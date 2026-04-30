import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../models/exercise.dart';
import 'active_workout.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final Schedule schedule;
  final int defaultRestSeconds;
  final VoidCallback onUpdate;

  const ScheduleDetailScreen({
    super.key,
    required this.schedule,
    required this.defaultRestSeconds,
    required this.onUpdate,
  });

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  String _techniqueLabel(IntensityTechnique technique) {
    switch (technique) {
      case IntensityTechnique.none:
        return 'Nessuna tecnica';
      case IntensityTechnique.dropSet:
        return 'Drop Set';
      case IntensityTechnique.restPause:
        return 'Rest-Pause';
      case IntensityTechnique.superSet:
        return 'Superset';
      case IntensityTechnique.cluster:
        return 'Cluster Set';
      case IntensityTechnique.isometric:
        return 'Isometria';
      case IntensityTechnique.negative:
        return 'Ripetizioni negative';
      case IntensityTechnique.forcedReps:
        return 'Ripetizioni forzate';
      case IntensityTechnique.topsetBackoff:
        return 'Top Set / Back off';
    }
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

  void _addExercise(
    String name,
    int sets,
    int reps,
    double weight,
    String notes,
    IntensityTechnique technique,
    int? backoffReps,
  ) {
    setState(() {
      widget.schedule.exercises.add(
        Exercise(
          name: name,
          set: sets,
          reps: reps,
          weight: weight,
          notes: notes,
          technique: technique,
          backoffReps: backoffReps,
        ),
      );
    });
    widget.onUpdate();
  }

  void _editExercise(
    int index,
    String name,
    int sets,
    int reps,
    double weight,
    String notes,
    IntensityTechnique technique,
    int? backoffReps,
  ) {
    setState(() {
      widget.schedule.exercises[index].name = name;
      widget.schedule.exercises[index].set = sets;
      widget.schedule.exercises[index].reps = reps;
      widget.schedule.exercises[index].weight = weight;
      widget.schedule.exercises[index].notes = notes;
      widget.schedule.exercises[index].technique = technique;
      widget.schedule.exercises[index].backoffReps = backoffReps;
    });
    widget.onUpdate();
  }

  void _removeExercise(int index) {
    if (index < 0 || index >= widget.schedule.exercises.length) {
      return;
    }

    final deletedExercise = widget.schedule.exercises[index];
    setState(() {
      widget.schedule.exercises.removeAt(index);
    });
    widget.onUpdate();

    _showUndoSnackBar(
      message: 'Esercizio eliminato.',
      onUndo: () {
        if (!mounted || widget.schedule.exercises.contains(deletedExercise)) {
          return;
        }

        setState(() {
          final restoreIndex = index > widget.schedule.exercises.length
              ? widget.schedule.exercises.length
              : index;
          widget.schedule.exercises.insert(restoreIndex, deletedExercise);
        });
        widget.onUpdate();
      },
    );
  }

  void _showExerciseDialog({int? indexToEdit, Exercise? exerciseToEdit}) {
    final bool isEditing = exerciseToEdit != null && indexToEdit != null;
    IntensityTechnique selectedTechnique = isEditing
        ? exerciseToEdit.technique
        : IntensityTechnique.none;

    final nameController = TextEditingController(
      text: isEditing ? exerciseToEdit.name : '',
    );
    final setsController = TextEditingController(
      text: isEditing ? exerciseToEdit.set.toString() : '',
    );
    final repsController = TextEditingController(
      text: isEditing ? exerciseToEdit.reps.toString() : '',
    );
    final topSetRepsController = TextEditingController(
      text: isEditing ? exerciseToEdit.reps.toString() : '',
    );
    final backoffRepsController = TextEditingController(
      text:
          isEditing &&
              exerciseToEdit.technique == IntensityTechnique.topsetBackoff
          ? (exerciseToEdit.backoffReps ?? exerciseToEdit.reps).toString()
          : '',
    );
    final weightController = TextEditingController(
      text: isEditing ? exerciseToEdit.weight.toString() : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? exerciseToEdit.notes : '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Modifica Esercizio' : 'Nuovo Esercizio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome (es. Squat)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IntensityTechnique>(
                  initialValue: selectedTechnique,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tecnica di intensità',
                  ),
                  items: IntensityTechnique.values
                      .map(
                        (technique) => DropdownMenuItem<IntensityTechnique>(
                          value: technique,
                          child: Text(_techniqueLabel(technique)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setDialogState(() {
                      selectedTechnique = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (selectedTechnique == IntensityTechnique.topsetBackoff) ...[
                  TextField(
                    controller: topSetRepsController,
                    decoration: const InputDecoration(
                      labelText: 'Top Set - Ripetizioni',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: backoffRepsController,
                    decoration: const InputDecoration(
                      labelText: 'Back off - Ripetizioni',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsController,
                          decoration: const InputDecoration(labelText: 'Serie'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: repsController,
                          decoration: const InputDecoration(
                            labelText: 'Ripetizioni',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                final bool isBackoff =
                    selectedTechnique == IntensityTechnique.topsetBackoff;

                final int? parsedSets = isBackoff
                    ? 2
                    : int.tryParse(setsController.text);
                final int? parsedReps = isBackoff
                    ? int.tryParse(topSetRepsController.text)
                    : int.tryParse(repsController.text);
                final int? parsedBackoffReps = isBackoff
                    ? int.tryParse(backoffRepsController.text)
                    : null;

                if (nameController.text.isEmpty ||
                    parsedSets == null ||
                    parsedReps == null ||
                    weightController.text.isEmpty ||
                    (isBackoff && parsedBackoffReps == null)) {
                  return;
                }

                if (isEditing) {
                  _editExercise(
                    indexToEdit,
                    nameController.text,
                    parsedSets,
                    parsedReps,
                    double.tryParse(weightController.text) ?? 0.0,
                    notesController.text,
                    selectedTechnique,
                    parsedBackoffReps,
                  );
                } else {
                  _addExercise(
                    nameController.text,
                    parsedSets,
                    parsedReps,
                    double.tryParse(weightController.text) ?? 0.0,
                    notesController.text,
                    selectedTechnique,
                    parsedBackoffReps,
                  );
                }
                Navigator.pop(context);
              },
              child: Text(isEditing ? 'Salva' : 'Aggiungi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule.title),
        actions: [
          TextButton(
            onPressed: () {
              if (widget.schedule.exercises.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Aggiungi degli esercizi prima di allenarti!',
                    ),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveWorkoutScreen(
                    schedule: widget.schedule,
                    defaultRestSeconds: widget.defaultRestSeconds,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            child: const Text(
              'ALLENATI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: widget.schedule.exercises.isEmpty
          ? const Center(child: Text('Nessun esercizio, iniziamo!'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.schedule.exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exercise = widget.schedule.exercises[index];
                return Dismissible(
                  key: ValueKey(exercise.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeExercise(index),
                  background: Container(
                    color: colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: colorScheme.onError),
                  ),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.fitness_center,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        exercise.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${exercise.technique == IntensityTechnique.topsetBackoff && exercise.backoffReps != null ? '2 set | Top Set ${exercise.reps} reps / Back off ${exercise.backoffReps} reps | ${exercise.weight} kg' : '${exercise.set} set x ${exercise.reps} reps | ${exercise.weight} kg'}'
                        '\nTecnica: ${_techniqueLabel(exercise.technique)}'
                        '${exercise.notes.trim().isNotEmpty ? '\nNote: ${exercise.notes}' : ''}',
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExerciseDialog(),
        label: const Text('Add Exercise'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
