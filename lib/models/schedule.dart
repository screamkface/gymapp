import 'exercise.dart';

class Schedule {
  String title;
  int week;
  DateTime createdAt;
  List<Exercise> exercises;
  bool isArchived;

  Schedule({
    required this.title,
    required this.week,
    required this.createdAt,
    required this.exercises,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'week': week,
    'createdAt': createdAt.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isArchived': isArchived,
  };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    title: json['title'],
    week: json['week'],
    createdAt: DateTime.parse(json['createdAt']),
    exercises:
        (json['exercises'] as List?)
            ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    isArchived: json['isArchived'] as bool? ?? false,
  );
}
