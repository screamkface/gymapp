import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise.dart';
import '../models/schedule.dart';
import '../models/workout.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Schedule schedule;
  final int defaultRestSeconds;

  const ActiveWorkoutScreen({
    super.key,
    required this.schedule,
    required this.defaultRestSeconds,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late WorkoutSession session;
  Timer? _restTimer;
  final Map<String, int> _restSecondsByExerciseId = {};

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _restSecondsFor(WorkoutExercise exercise) {
    return exercise.restSeconds ?? widget.defaultRestSeconds;
  }

  void _ensureRestTimerRunning() {
    if (_restTimer != null) {
      return;
    }

    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _restTimer?.cancel();
        _restTimer = null;
        return;
      }

      final updatedCountdowns = <String, int>{};
      _restSecondsByExerciseId.forEach((exerciseId, remainingSeconds) {
        if (remainingSeconds > 1) {
          updatedCountdowns[exerciseId] = remainingSeconds - 1;
        }
      });

      setState(() {
        _restSecondsByExerciseId
          ..clear()
          ..addAll(updatedCountdowns);
      });

      if (_restSecondsByExerciseId.isEmpty) {
        _restTimer?.cancel();
        _restTimer = null;
      }
    });
  }

  void _startRestForExercise(WorkoutExercise exercise) {
    final restSeconds = _restSecondsFor(exercise);
    if (restSeconds <= 0) {
      return;
    }

    setState(() {
      _restSecondsByExerciseId[exercise.id] = restSeconds;
    });
    _ensureRestTimerRunning();
  }

  void _addThirtySeconds(WorkoutExercise exercise) {
    final currentSeconds = _restSecondsByExerciseId[exercise.id];
    if (currentSeconds == null) {
      _startRestForExercise(exercise);
      return;
    }

    setState(() {
      _restSecondsByExerciseId[exercise.id] = currentSeconds + 30;
    });
    _ensureRestTimerRunning();
  }

  void _stopRestForExercise(WorkoutExercise exercise) {
    setState(() {
      _restSecondsByExerciseId.remove(exercise.id);
    });

    if (_restSecondsByExerciseId.isEmpty) {
      _restTimer?.cancel();
      _restTimer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    session = WorkoutSession(
      scheduleTitle: widget.schedule.title,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      exercises: widget.schedule.exercises.map((exercise) {
        final isBackoff =
            exercise.technique == IntensityTechnique.topsetBackoff &&
            exercise.backoffReps != null;

        final sets = isBackoff
            ? [
                ExerciseSet(weight: exercise.weight, reps: exercise.reps),
                ExerciseSet(weight: exercise.weight, reps: exercise.backoffReps!),
              ]
            : List.generate(
                exercise.set,
                (_) => ExerciseSet(weight: exercise.weight, reps: exercise.reps),
              );

        return WorkoutExercise(
          name: exercise.name,
          notes: exercise.notes,
          technique: exercise.technique,
          restSeconds: exercise.restSeconds,
          sets: sets,
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _finishWorkout() async {
    session.endTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('history');
    List<WorkoutSession> history = [];

    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      history = decoded.map((entry) => WorkoutSession.fromJson(entry)).toList();
    }

    history.add(session);
    await prefs.setString(
      'history',
      jsonEncode(history.map((entry) => entry.toJson()).toList()),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _addSet(WorkoutExercise exercise) {
    setState(() {
      if (exercise.sets.isNotEmpty) {
        final last = exercise.sets.last;
        exercise.sets.add(ExerciseSet(weight: last.weight, reps: last.reps));
      } else {
        exercise.sets.add(ExerciseSet(weight: 0, reps: 10));
      }
    });
  }

  void _showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
  }) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'ANNULLA', onPressed: onUndo),
      ),
    );
  }

  void _removeSet(WorkoutExercise exercise, int index) {
    if (index < 0 || index >= exercise.sets.length) {
      return;
    }

    final deletedSet = exercise.sets[index];
    setState(() {
      exercise.sets.removeAt(index);
    });

    _showUndoSnackBar(
      message: 'Set eliminato.',
      onUndo: () {
        if (!mounted || exercise.sets.contains(deletedSet)) {
          return;
        }

        setState(() {
          final restoreIndex = index > exercise.sets.length
              ? exercise.sets.length
              : index;
          exercise.sets.insert(restoreIndex, deletedSet);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final compactInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Allenamento: ${session.scheduleTitle}'),
        actions: [
          TextButton(
            onPressed: () async {
              final hasUnfinished = session.exercises.any(
                (exercise) => exercise.sets.any((set) => !set.isCompleted),
              );

              if (hasUnfinished) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Completare?'),
                    content: const Text(
                      'Ci sono set non completati. Vuoi finire lo stesso? I set non completati saranno ignorati nella cronologia (o salvati come non fatti).',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annulla'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Finisci'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) {
                  return;
                }
              }

              await _finishWorkout();
            },
            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            child: const Text(
              'FINE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: session.exercises.length,
        itemBuilder: (context, exIndex) {
          final exercise = session.exercises[exIndex];
          final activeRestSeconds = _restSecondsByExerciseId[exercise.id];
          final restSeconds = activeRestSeconds ?? _restSecondsFor(exercise);

          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  if (exercise.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      exercise.notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        activeRestSeconds == null
                            ? 'Recupero per esercizio: ${_formatDuration(restSeconds)}'
                            : 'Recupero in corso: ${_formatDuration(restSeconds)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Aggiungi 30 secondi',
                        onPressed: () => _addThirtySeconds(exercise),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Ferma recupero',
                        onPressed: activeRestSeconds == null
                            ? null
                            : () => _stopRestForExercise(exercise),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      SizedBox(
                        width: 30,
                        child: Text(
                          'SET',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'KG',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'REPS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Center(child: Icon(Icons.check)),
                      ),
                    ],
                  ),
                  const Divider(),
                  ...List.generate(exercise.sets.length, (setIndex) {
                    final exSet = exercise.sets[setIndex];
                    final setLabel =
                        exercise.technique == IntensityTechnique.topsetBackoff
                            ? (setIndex == 0 ? 'Top Set' : 'Back off')
                            : '${setIndex + 1}';

                    return Dismissible(
                      key: ValueKey(exSet.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _removeSet(exercise, setIndex),
                      background: Container(
                        color: colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete, color: colorScheme.onError),
                      ),
                      child: Container(
                        color: exSet.isCompleted
                            ? colorScheme.tertiaryContainer.withValues(
                                alpha: 0.55,
                              )
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                setLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: TextFormField(
                                  initialValue: exSet.weight.toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    border: compactInputBorder,
                                    enabledBorder: compactInputBorder,
                                    focusedBorder: compactInputBorder.copyWith(
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    exSet.weight = double.tryParse(value) ?? 0.0;
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: TextFormField(
                                  initialValue: exSet.reps.toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    border: compactInputBorder,
                                    enabledBorder: compactInputBorder,
                                    focusedBorder: compactInputBorder.copyWith(
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    exSet.reps = int.tryParse(value) ?? 0;
                                  },
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  exSet.isCompleted = !exSet.isCompleted;
                                  if (exSet.isCompleted) {
                                    _startRestForExercise(exercise);
                                  }
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: exSet.isCompleted
                                      ? colorScheme.tertiary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: exSet.isCompleted
                                      ? colorScheme.onTertiary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _addSet(exercise),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi set'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
