import 'model_id.dart';
import 'exercise.dart';

class ExerciseSet {
  final String id;
  double weight;
  int reps;
  bool isCompleted;

  ExerciseSet({
    String? id,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
  }) : id = id ?? newModelId('set');

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'reps': reps,
    'isCompleted': isCompleted,
  };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
    id: json['id'] as String?,
    weight: (json['weight'] as num).toDouble(),
    reps: json['reps'] as int,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

class WorkoutExercise {
  final String id;
  String name;
  String notes;
  IntensityTechnique technique;
  List<ExerciseSet> sets;

  WorkoutExercise({
    String? id,
    required this.name,
    required this.notes,
    required this.technique,
    required this.sets,
  }) : id = id ?? newModelId('workout_exercise');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notes': notes,
    'technique': technique.name,
    'sets': sets.map((e) => e.toJson()).toList(),
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    IntensityTechnique parsedTechnique = IntensityTechnique.none;
    if (json['technique'] != null) {
      try {
        parsedTechnique = IntensityTechnique.values.byName(json['technique']);
      } catch (e) {
        parsedTechnique = IntensityTechnique.none;
      }
    }

    return WorkoutExercise(
      id: json['id'] as String?,
      name: json['name'] as String,
      notes: json['notes'] as String? ?? '',
      technique: parsedTechnique,
      sets: (json['sets'] as List)
          .map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WorkoutSession {
  final String id;
  String scheduleTitle;
  DateTime startTime;
  DateTime endTime;
  List<WorkoutExercise> exercises;

  WorkoutSession({
    String? id,
    required this.scheduleTitle,
    required this.startTime,
    required this.endTime,
    required this.exercises,
  }) : id = id ?? newModelId('workout_session');

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduleTitle': scheduleTitle,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] as String?,
    scheduleTitle: json['scheduleTitle'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    exercises: (json['exercises'] as List)
        .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
