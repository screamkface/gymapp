import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp/ai_coach/ai_coach_models.dart';
import 'package:gymapp/ai_coach/ai_coach_structured_context.dart';
import 'package:gymapp/ai_coach/local_ai_coach_service.dart';
import 'package:gymapp/ai_coach/local_llm_engine.dart';
import 'package:gymapp/ai_coach/training_context_builder.dart';
import 'package:gymapp/app_data_store.dart';
import 'package:gymapp/models/exercise.dart';
import 'package:gymapp/models/workout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('structured notes capsule keeps explicit note lines inside budget', () {
    final context = <String, dynamic>{
      'workouts': [
        {
          'name': 'Push',
          'start_time': '2026-09-05T18:00:00.000',
          'exercises': const <dynamic>[],
        },
      ],
      'notes': List.generate(
        12,
        (index) =>
            'Nota $index: controllo tecnico buono ma ultima ripetizione lenta.',
      ),
    };

    final envelope = AiCoachStructuredContext.build(
      task: AiCoachTask.notesSummary,
      context: context,
      capsuleBudget: 1200,
    );
    final capsule = envelope['capsule'] as String;

    expect(envelope['context_format'], 'mobile_structured_capsule_v1');
    expect(envelope['user_data_available'], isTrue);
    expect(capsule, contains('NOTE Nota 0'));
    expect(capsule.length, lessThanOrEqualTo(1200));
  });

  test('adjustment capsule preserves exact mutation identifiers', () {
    final envelope = AiCoachStructuredContext.build(
      task: AiCoachTask.suggestedAdjustments,
      context: const {
        'active_plans': [
          {
            'id': 'schedule-push',
            'title': 'Push',
            'exercises': [
              {
                'id': 'bench-plan',
                'name': 'Panca piana',
                'set': 4,
                'targetMinReps': 6,
                'targetMaxReps': 8,
                'weight': 80,
              },
            ],
          },
        ],
      },
      capsuleBudget: 1000,
    );
    final capsule = envelope['capsule'] as String;

    expect(capsule, contains('PLAN_ID sid=schedule-push'));
    expect(capsule, contains('EX_ID sid=schedule-push eid=bench-plan'));
  });

  test('structured Gemma path refreshes persistence and uses mobile capsule', () async {
    final persisted = _session(
      id: 'persisted',
      title: 'Persisted Push',
      start: DateTime(2026, 9, 5, 18),
      weight: 82.5,
    );
    await AppDataStore.saveHistory([persisted]);

    final stale = _session(
      id: 'stale',
      title: 'Stale Push',
      start: DateTime(2026, 9, 4, 18),
      weight: 60,
    );
    final engine = _CapturingStructuredGemmaEngine();
    final service = LocalAiCoachService(
      engine: engine,
      contextBuilder: TrainingContextBuilder(now: DateTime(2026, 9, 6)),
    );

    final report = await service.generateWeeklyReport(
      history: [stale],
      schedules: const [],
    );

    expect(report.sessionsCompleted, 1);
    expect(engine.lastPrompt, contains('mobile_structured_capsule_v1'));
    expect(engine.lastPrompt, contains('Persisted Push'));
    expect(engine.lastPrompt, contains('82.5x8'));
    expect(engine.lastPrompt, isNot(contains('Stale Push')));
    expect(engine.lastPrompt, contains('USER_DATA_AVAILABLE=true'));
  });
}

WorkoutSession _session({
  required String id,
  required String title,
  required DateTime start,
  required double weight,
}) {
  return WorkoutSession(
    id: id,
    scheduleTitle: title,
    startTime: start,
    endTime: start.add(const Duration(minutes: 60)),
    exercises: [
      WorkoutExercise(
        id: '$id-bench',
        name: 'Panca piana',
        notes: 'Controllo buono',
        muscleGroup: MuscleGroup.chest,
        technique: IntensityTechnique.none,
        sets: [
          ExerciseSet(
            id: '$id-set',
            weight: weight,
            reps: 8,
            isCompleted: true,
            rir: 2,
          ),
        ],
      ),
    ],
  );
}

class _CapturingStructuredGemmaEngine extends FlutterGemmaLocalLlmEngine {
  String lastPrompt = '';

  @override
  Future<void> initialize() async {}

  @override
  Future<String> generateStructuredJson(
    String prompt,
    Map<String, dynamic> schema,
  ) async {
    lastPrompt = prompt;
    return '''
{
  "summary": "1 sessione",
  "sessions_completed": 1,
  "main_improvements": [],
  "possible_weak_points": [],
  "stalled_exercises": [],
  "best_progressions": [],
  "recovery_notes": [],
  "practical_suggestions": []
}
''';
  }
}
