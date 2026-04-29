import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Timer settings
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isTimerActive = false;

  @override
  void initState() {
    super.initState();
    session = WorkoutSession(
      scheduleTitle: widget.schedule.title,
      startTime: DateTime.now(),
      endTime: DateTime.now(), // verrà aggiornato alla fine
      exercises: widget.schedule.exercises.map((e) {
        return WorkoutExercise(
          name: e.name,
          sets: List.generate(
            e.set,
            (index) => ExerciseSet(weight: e.weight, reps: e.reps),
          ),
        );
      }).toList(),
    );
  }

  void _startTimer() {
    _restTimer?.cancel();
    setState(() {
      _restSeconds = widget.defaultRestSeconds;
      _isTimerActive = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        setState(() {
          _restSeconds--;
        });
      } else {
        _stopTimer();
        // Optional: play sound or vibrate
      }
    });
  }

  void _stopTimer() {
    _restTimer?.cancel();
    setState(() {
      _isTimerActive = false;
      _restSeconds = 0;
    });
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
      history = decoded.map((e) => WorkoutSession.fromJson(e)).toList();
    }

    history.add(session);
    await prefs.setString(
      'history',
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );

    if (mounted) {
      Navigator.pop(context, true); // Ritorna true se completato
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
              // Verifica se ci sono set non completati
              bool hasUnfinished = session.exercises.any(
                (e) => e.sets.any((s) => !s.isCompleted),
              );
              if (hasUnfinished) {
                bool? confirm = await showDialog(
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
                if (confirm != true) return;
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
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: session.exercises.length,
        itemBuilder: (context, exIndex) {
          final exercise = session.exercises[exIndex];
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
                              width: 30,
                              child: Text(
                                '${setIndex + 1}',
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
                                  onChanged: (val) {
                                    exSet.weight = double.tryParse(val) ?? 0.0;
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
                                  onChanged: (val) {
                                    exSet.reps = int.tryParse(val) ?? 0;
                                  },
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  exSet.isCompleted = !exSet.isCompleted;
                                  if (exSet.isCompleted) {
                                    _startTimer();
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
      bottomSheet: _isTimerActive ? _buildRestTimer() : null,
    );
  }

  Widget _buildRestTimer() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    int min = _restSeconds ~/ 60;
    int sec = _restSeconds % 60;
    String timeStr =
        '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';

    return Container(
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: SafeArea(
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colorScheme.onPrimaryContainer),
          child: IconTheme.merge(
            data: IconThemeData(color: colorScheme.onPrimaryContainer),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.timer),
                const Text(
                  'Recupero',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _restSeconds += 30),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _stopTimer,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
