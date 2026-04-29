// workout.dart

class ExerciseSet {
  double weight;
  int reps;
  bool isCompleted;

  ExerciseSet({
    required this.weight,
    required this.reps,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'isCompleted': isCompleted,
      };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        weight: (json['weight'] as num).toDouble(),
        reps: json['reps'] as int,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class WorkoutExercise {
  String name;
  List<ExerciseSet> sets;

  WorkoutExercise({
    required this.name,
    required this.sets,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets.map((e) => e.toJson()).toList(),
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        name: json['name'] as String,
        sets: (json['sets'] as List)
            .map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutSession {
  String scheduleTitle;
  DateTime startTime;
  DateTime endTime;
  List<WorkoutExercise> exercises;

  WorkoutSession({
    required this.scheduleTitle,
    required this.startTime,
    required this.endTime,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'scheduleTitle': scheduleTitle,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        scheduleTitle: json['scheduleTitle'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        exercises: (json['exercises'] as List)
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
