import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp/models/exercise.dart';
import 'package:gymapp/models/schedule.dart';
import 'package:gymapp/models/workout.dart';
import 'package:gymapp/screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('schedule deletion can be undone', (tester) async {
    final schedule = Schedule(
      id: 'schedule_1',
      title: 'Push',
      week: 1,
      createdAt: DateTime(2026),
      exercises: [
        Exercise(
          id: 'exercise_1',
          name: 'Panca',
          reps: 8,
          set: 3,
          notes: '',
          weight: 80,
          technique: IntensityTechnique.none,
        ),
      ],
    );

    SharedPreferences.setMockInitialValues({
      'schedules': jsonEncode([schedule.toJson()]),
      'history': '[]',
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);

    await tester.drag(find.text('Push'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsNothing);
    expect(find.text('Scheda eliminata.'), findsOneWidget);

    await tester.tap(find.text('ANNULLA'));
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final storedSchedules =
        jsonDecode(prefs.getString('schedules')!) as List<dynamic>;
    expect(storedSchedules.single['id'], 'schedule_1');
  });

  testWidgets('history deletion can be undone', (tester) async {
    final session = WorkoutSession(
      id: 'session_1',
      scheduleTitle: 'Pull',
      startTime: DateTime(2026, 4, 1, 10),
      endTime: DateTime(2026, 4, 1, 11),
      exercises: [
        WorkoutExercise(
          id: 'workout_exercise_1',
          name: 'Rematore',
          sets: [
            ExerciseSet(id: 'set_1', weight: 60, reps: 10, isCompleted: true),
          ],
        ),
      ],
    );

    SharedPreferences.setMockInitialValues({
      'schedules': '[]',
      'history': jsonEncode([session.toJson()]),
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cronologia'));
    await tester.pumpAndSettle();

    expect(find.text('Pull'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Pull'), findsNothing);
    expect(find.text('Allenamento eliminato.'), findsOneWidget);

    await tester.tap(find.text('ANNULLA'));
    await tester.pumpAndSettle();

    expect(find.text('Pull'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final storedHistory =
        jsonDecode(prefs.getString('history')!) as List<dynamic>;
    expect(storedHistory.single['id'], 'session_1');
  });

  test('legacy json gets generated ids and keeps them after serialization', () {
    final schedule = Schedule.fromJson(<String, dynamic>{
      'title': 'Legacy',
      'week': 1,
      'createdAt': DateTime(2026).toIso8601String(),
      'exercises': [
        <String, dynamic>{
          'name': 'Squat',
          'reps': 5,
          'set': 5,
          'notes': '',
          'weight': 100,
        },
      ],
    });

    final restored = Schedule.fromJson(schedule.toJson());

    expect(schedule.id, isNotEmpty);
    expect(schedule.exercises.single.id, isNotEmpty);
    expect(restored.id, schedule.id);
    expect(restored.exercises.single.id, schedule.exercises.single.id);
  });
}
