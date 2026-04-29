import 'exercise.dart';
import 'model_id.dart';

class Schedule {
  final String id;
  String title;
  int week;
  DateTime createdAt;
  List<Exercise> exercises;
  bool isArchived;

  Schedule({
    String? id,
    required this.title,
    required this.week,
    required this.createdAt,
    required this.exercises,
    this.isArchived = false,
  }) : id = id ?? newModelId('schedule');

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'week': week,
    'createdAt': createdAt.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isArchived': isArchived,
  };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    id: json['id'] as String?,
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
