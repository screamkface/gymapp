import 'model_id.dart';

class Exercise {
  final String id;
  String name;
  int reps;
  int set;
  String notes;
  double weight;

  Exercise({
    String? id,
    required this.name,
    required this.reps,
    required this.set,
    required this.notes,
    required this.weight,
  }) : id = id ?? newModelId('exercise');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'reps': reps,
    'set': set,
    'notes': notes,
    'weight': weight,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String?,
    name: json['name'],
    reps: json['reps'],
    set: json['set'],
    notes: json['notes'],
    weight: json['weight'] is int
        ? (json['weight'] as int).toDouble()
        : json['weight'],
  );
}
