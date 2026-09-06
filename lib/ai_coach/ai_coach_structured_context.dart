import 'package:flutter/foundation.dart';

import 'ai_coach_context_capsule.dart';
import 'ai_coach_context_router.dart';
import 'ai_coach_models.dart';

class AiCoachStructuredContextDiagnostics {
  final AiCoachTask task;
  final int capsuleChars;
  final int budgetChars;
  final bool userDataAvailable;
  final bool referenceDataAvailable;

  const AiCoachStructuredContextDiagnostics({
    required this.task,
    required this.capsuleChars,
    required this.budgetChars,
    required this.userDataAvailable,
    required this.referenceDataAvailable,
  });

  String toLogLine() =>
      'task=${task.promptName} chars=$capsuleChars/$budgetChars '
      'user_data=$userDataAvailable reference_data=$referenceDataAvailable';
}

/// Builds a deterministic, task-specific envelope for structured on-device
/// inference. The payload is intentionally dense: a small Gemma model should
/// spend its KV cache on user facts and the output schema, not verbose JSON.
class AiCoachStructuredContext {
  static const int defaultCapsuleBudget = 1900;
  static AiCoachStructuredContextDiagnostics? lastDiagnostics;

  const AiCoachStructuredContext._();

  static Map<String, dynamic> build({
    required AiCoachTask task,
    required Map<String, dynamic> context,
    int capsuleBudget = defaultCapsuleBudget,
  }) {
    final intent = _intentForTask(task);
    final reserve = _supplementReserve(task);
    final baseBudget = (capsuleBudget - reserve).clamp(500, capsuleBudget);
    final base = const AiCoachContextCapsuleBuilder().build(
      context: context,
      intent: intent,
      charBudget: baseBudget,
    );

    final supplement = _taskSupplement(task, context);
    final capsule = _fitParts([base, supplement], capsuleBudget);
    final capsuleDiagnostics = AiCoachContextCapsuleBuilder.lastDiagnostics;
    final userDataAvailable =
        capsuleDiagnostics?.userDataAvailable ?? _hasUserData(context);
    final referenceDataAvailable =
        capsuleDiagnostics?.referenceDataAvailable ??
        (context['exercise_catalog'] is Map &&
            (context['exercise_catalog'] as Map).isNotEmpty);

    final diagnostics = AiCoachStructuredContextDiagnostics(
      task: task,
      capsuleChars: capsule.length,
      budgetChars: capsuleBudget,
      userDataAvailable: userDataAvailable,
      referenceDataAvailable: referenceDataAvailable,
    );
    lastDiagnostics = diagnostics;
    if (kDebugMode) {
      debugPrint('[AI_COACH_STRUCTURED_CONTEXT] ${diagnostics.toLogLine()}');
    }

    return <String, dynamic>{
      'context_format': 'mobile_structured_capsule_v1',
      'task': task.promptName,
      'user_data_available': userDataAvailable,
      'reference_data_available': referenceDataAvailable,
      'capsule': capsule,
    };
  }

  static AiCoachChatIntent _intentForTask(AiCoachTask task) {
    return switch (task) {
      AiCoachTask.workoutRecap => AiCoachChatIntent.progress,
      AiCoachTask.weeklyReport => AiCoachChatIntent.progress,
      AiCoachTask.weakPointAnalysis => AiCoachChatIntent.progress,
      AiCoachTask.notesSummary => AiCoachChatIntent.general,
      AiCoachTask.suggestedAdjustments => AiCoachChatIntent.progression,
      AiCoachTask.bodyPhotoAnalysis => AiCoachChatIntent.progress,
      AiCoachTask.freeChat => AiCoachChatIntent.general,
    };
  }

  static int _supplementReserve(AiCoachTask task) {
    return switch (task) {
      AiCoachTask.notesSummary => 520,
      AiCoachTask.suggestedAdjustments => 520,
      AiCoachTask.bodyPhotoAnalysis => 280,
      _ => 0,
    };
  }

  static String _taskSupplement(
    AiCoachTask task,
    Map<String, dynamic> context,
  ) {
    return switch (task) {
      AiCoachTask.notesSummary => _notesSupplement(context),
      AiCoachTask.suggestedAdjustments => _planIdSupplement(context),
      AiCoachTask.bodyPhotoAnalysis => _photoSupplement(context),
      _ => '',
    };
  }

  static String _notesSupplement(Map<String, dynamic> context) {
    final lines = <String>[];
    for (final raw in (context['notes'] as List? ?? const <dynamic>[]).take(10)) {
      final text = raw.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty) continue;
      lines.add('NOTE ${_clip(text, 150)}');
    }
    return lines.join('\n');
  }

  static String _planIdSupplement(Map<String, dynamic> context) {
    final lines = <String>[];
    final plans = (context['active_plans'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .take(3);
    for (final rawPlan in plans) {
      final plan = Map<String, dynamic>.from(rawPlan);
      final scheduleId = _text(plan['id']);
      final title = _text(plan['title']);
      if (scheduleId.isNotEmpty) {
        lines.add('PLAN_ID sid=$scheduleId title=${_clip(title, 60)}');
      }
      for (final rawExercise
          in (plan['exercises'] as List? ?? const <dynamic>[])
              .whereType<Map>()
              .take(12)) {
        final exercise = Map<String, dynamic>.from(rawExercise);
        final exerciseId = _text(exercise['id']);
        final name = _text(exercise['name']);
        if (exerciseId.isNotEmpty) {
          lines.add(
            'EX_ID sid=$scheduleId eid=$exerciseId name=${_clip(name, 60)}',
          );
        }
      }
    }
    return lines.join('\n');
  }

  static String _photoSupplement(Map<String, dynamic> context) {
    final lines = <String>[];
    final photos = context['photo_inputs'];
    if (photos is! List) return '';
    for (final raw in photos.take(4)) {
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final label = _text(map['label']);
        final width = _text(map['width']);
        final height = _text(map['height']);
        lines.add(
          'PHOTO ${label.isEmpty ? 'image' : _clip(label, 80)}'
          '${width.isEmpty || height.isEmpty ? '' : ' ${width}x$height'}',
        );
      } else {
        final text = raw.toString().trim();
        if (text.isNotEmpty) lines.add('PHOTO ${_clip(text, 100)}');
      }
    }
    return lines.join('\n');
  }

  static String _fitParts(List<String> parts, int budget) {
    final buffer = StringBuffer();
    for (final raw in parts) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final separator = buffer.isEmpty ? '' : '\n';
      final remaining = budget - buffer.length - separator.length;
      if (remaining <= 0) break;
      buffer.write(separator);
      buffer.write(_clip(part, remaining));
    }
    return buffer.toString();
  }

  static bool _hasUserData(Map<String, dynamic> context) {
    bool nonEmptyList(String key) =>
        context[key] is List && (context[key] as List).isNotEmpty;
    bool nonEmptyMap(String key) =>
        context[key] is Map && (context[key] as Map).isNotEmpty;
    return nonEmptyList('active_plans') ||
        nonEmptyList('workouts') ||
        nonEmptyList('body_logs') ||
        nonEmptyMap('verified_evidence') ||
        nonEmptyMap('deterministic_analytics') ||
        nonEmptyMap('user_profile') ||
        nonEmptyMap('memory');
  }

  static String _text(Object? value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }

  static String _clip(String value, int limit) {
    if (limit <= 0) return '';
    if (value.length <= limit) return value;
    if (limit == 1) return value.substring(0, 1);
    return '${value.substring(0, limit - 1)}…';
  }
}
