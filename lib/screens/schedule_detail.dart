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
  ) {
    setState(() {
      widget.schedule.exercises.add(
        Exercise(
          name: name,
          set: sets,
          reps: reps,
          weight: weight,
          notes: notes,
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
  ) {
    setState(() {
      widget.schedule.exercises[index].name = name;
      widget.schedule.exercises[index].set = sets;
      widget.schedule.exercises[index].reps = reps;
      widget.schedule.exercises[index].weight = weight;
      widget.schedule.exercises[index].notes = notes;
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

    final nameController = TextEditingController(
      text: isEditing ? exerciseToEdit.name : '',
    );
    final setsController = TextEditingController(
      text: isEditing ? exerciseToEdit.set.toString() : '',
    );
    final repsController = TextEditingController(
      text: isEditing ? exerciseToEdit.reps.toString() : '',
    );
    final weightController = TextEditingController(
      text: isEditing ? exerciseToEdit.weight.toString() : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? exerciseToEdit.notes : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
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
              if (nameController.text.isNotEmpty &&
                  setsController.text.isNotEmpty &&
                  repsController.text.isNotEmpty) {
                if (isEditing) {
                  _editExercise(
                    indexToEdit,
                    nameController.text,
                    int.tryParse(setsController.text) ?? 3,
                    int.tryParse(repsController.text) ?? 10,
                    double.tryParse(weightController.text) ?? 0.0,
                    notesController.text,
                  );
                } else {
                  _addExercise(
                    nameController.text,
                    int.tryParse(setsController.text) ?? 3,
                    int.tryParse(repsController.text) ?? 10,
                    double.tryParse(weightController.text) ?? 0.0,
                    notesController.text,
                  );
                }
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? 'Salva' : 'Aggiungi'),
          ),
        ],
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
                        '${exercise.set} set x ${exercise.reps} reps | ${exercise.weight} kg'
                        '${exercise.notes.trim().isNotEmpty ? '\nNote: ${exercise.notes}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: colorScheme.primary),
                            onPressed: () {
                              _showExerciseDialog(
                                indexToEdit: index,
                                exerciseToEdit: exercise,
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: colorScheme.error),
                            onPressed: () {
                              _removeExercise(index);
                            },
                          ),
                        ],
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
