import 'model_id.dart';

// Definiamo un enum con le tecniche di intensità più comuni
enum IntensityTechnique {
  none,         // Nessuna tecnica (serie normale)
  dropSet,      // Stripping / Drop Set
  restPause,    // Rest-Pause
  superSet,     // Superset
  cluster,      // Cluster Set
  isometric,    // Isometria
  negative,     // Ripetizioni negative
  forcedReps,   // Ripetizioni forzate
  topsetBackoff, // Top Set + Back off
}

class Exercise {
  final String id;
  String name;
  int reps;
  int set;
  String notes;
  double weight;
  IntensityTechnique technique; // Aggiornato per usare l'enum
  int? backoffReps;
  int? restSeconds;

  Exercise({
    String? id,
    required this.name,
    required this.reps,
    required this.set,
    required this.notes,
    required this.weight,
    required this.technique,
    this.backoffReps,
    this.restSeconds,
  }) : id = id ?? newModelId('exercise');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'reps': reps,
    'set': set,
    'notes': notes,
    'weight': weight,
    'technique': technique.name, // Salviamo l'enum come Stringa (es: "dropSet")
    'backoffReps': backoffReps,
    'restSeconds': restSeconds,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // Gestione sicura del parsing dell'enum
    IntensityTechnique parsedTechnique = IntensityTechnique.none;
    if (json['technique'] != null) {
      try {
        parsedTechnique = IntensityTechnique.values.byName(json['technique']);
      } catch (e) {
        // Fallback in caso di valore non valido nel JSON
        parsedTechnique = IntensityTechnique.none;
      }
    }

    return Exercise(
      id: json['id'] as String?,
      name: json['name'],
      reps: json['reps'],
      set: json['set'],
      notes: json['notes'],
      weight: json['weight'] is int
          ? (json['weight'] as int).toDouble()
          : (json['weight'] ?? 0.0), // Aggiunto fallback per evitare null
      technique: parsedTechnique, // Ripristiniamo l'enum
      backoffReps: json['backoffReps'] as int?,
      restSeconds: json['restSeconds'] as int?,
    );
  }
}