import 'dart:core';
// Removed ffi import

class Exercise {
  String name;
  int reps;
  int set;
  String notes;
  double weight;

  Exercise({
    required this.name,
    required this.reps,
    required this.set,
    required this.notes,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'reps': reps,
        'set': set,
        'notes': notes,
        'weight': weight,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        name: json['name'],
        reps: json['reps'],
        set: json['set'],
        notes: json['notes'],
        weight: json['weight'] is int ? (json['weight'] as int).toDouble() : json['weight'],
      );
}
