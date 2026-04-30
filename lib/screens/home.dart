import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_preferences.dart';
import '../models/exercise.dart';
import '../models/schedule.dart';
import '../models/workout.dart';
import 'schedule_detail.dart';
import 'settings.dart';
import 'stats.dart';

enum _HomeAction { importCsv, exportCsv, exportBackup, restoreBackup }

enum _ScheduleMenuAction { toggleArchive, delete }

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const HomePage({
    super.key,
    this.themeMode = AppPreferences.defaultThemeMode,
    this.onThemeModeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Schedule> schedules = [];
  final List<WorkoutSession> history = [];

  int _currentIndex = 0;
  String _searchQuery = '';
  int? _selectedWeekFilter;
  bool _showArchived = false;
  int _defaultRestSeconds = AppPreferences.defaultRestSeconds;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSettings();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final schedulesJson = prefs.getString('schedules');
    final historyJson = prefs.getString('history');

    final loadedSchedules = schedulesJson == null
        ? <Schedule>[]
        : (jsonDecode(schedulesJson) as List<dynamic>)
              .map(
                (e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
    final loadedHistory = historyJson == null
        ? <WorkoutSession>[]
        : (jsonDecode(historyJson) as List<dynamic>)
              .map(
                (e) => WorkoutSession.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      schedules
        ..clear()
        ..addAll(loadedSchedules);
      history
        ..clear()
        ..addAll(loadedHistory);
      _sortSchedules();
    });
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'schedules',
      jsonEncode(schedules.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'history',
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveAllData() async {
    await Future.wait([_saveSchedules(), _saveHistory()]);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _defaultRestSeconds =
          prefs.getInt(AppPreferences.defaultRestSecondsKey) ??
          AppPreferences.defaultRestSeconds;
    });
  }

  Future<void> _setDefaultRestSeconds(int seconds) async {
    final normalizedSeconds = seconds.clamp(
      AppPreferences.minRestSeconds,
      AppPreferences.maxRestSeconds,
    );

    setState(() {
      _defaultRestSeconds = normalizedSeconds;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppPreferences.defaultRestSecondsKey, normalizedSeconds);
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

  void _sortSchedules() {
    schedules.sort((a, b) {
      if (a.isArchived != b.isArchived) {
        return a.isArchived ? 1 : -1;
      }

      final weekCompare = a.week.compareTo(b.week);
      if (weekCompare != 0) {
        return weekCompare;
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  Future<void> _deleteHistory(int index) async {
    if (index < 0 || index >= history.length) {
      return;
    }

    final deletedSession = history[index];
    setState(() {
      history.removeAt(index);
    });
    await _saveHistory();

    _showUndoSnackBar(
      message: 'Allenamento eliminato.',
      onUndo: () {
        if (!mounted || history.contains(deletedSession)) {
          return;
        }

        setState(() {
          final restoreIndex = index > history.length ? history.length : index;
          history.insert(restoreIndex, deletedSession);
        });
        _saveHistory();
      },
    );
  }

  Future<void> _showInfo(String message) async {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String> _readPickedTextFile(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Il file selezionato non contiene dati leggibili.');
    }

    return utf8.decode(bytes);
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\uFEFF', '');
  }

  bool _looksLikeCsvHeader(List<dynamic> row) {
    if (row.length < 7) {
      return false;
    }

    final first = row[0].toString().trim().toLowerCase();
    final second = row[1].toString().trim().toLowerCase();
    final third = row[2].toString().trim().toLowerCase();

    return first.contains('title') ||
        first.contains('titolo') ||
        second.contains('week') ||
        second.contains('settimana') ||
        third.contains('exercise') ||
        third.contains('eserc');
  }

  List<List<dynamic>> _decodeCsv(String rawText) {
    final normalizedText = _normalizeText(rawText);
    List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
    ).convert(normalizedText);

    if (rows.isNotEmpty &&
        rows.first.length < 7 &&
        normalizedText.contains(';')) {
      rows = const CsvToListConverter(
        fieldDelimiter: ';',
        eol: '\n',
      ).convert(normalizedText);
    }

    if (rows.isNotEmpty && _looksLikeCsvHeader(rows.first)) {
      rows = rows.skip(1).toList();
    }

    return rows;
  }

  bool _exerciseAlreadyExists(Schedule schedule, Exercise candidate) {
    return schedule.exercises.any((exercise) {
      return exercise.name == candidate.name &&
          exercise.set == candidate.set &&
          exercise.reps == candidate.reps &&
          exercise.backoffReps == candidate.backoffReps &&
          exercise.technique == candidate.technique &&
          exercise.weight == candidate.weight &&
          exercise.notes.trim() == candidate.notes.trim();
    });
  }

  String _buildSchedulesCsv() {
    final rows = <List<dynamic>>[];

    for (final schedule in schedules) {
      for (final exercise in schedule.exercises) {
        rows.add([
          schedule.title,
          schedule.week,
          exercise.name,
          exercise.set,
          exercise.reps,
          exercise.weight,
          exercise.notes,
        ]);
      }
    }

    if (rows.isEmpty) {
      return '';
    }

    return const ListToCsvConverter(
      fieldDelimiter: ',',
      eol: '\n',
    ).convert(rows);
  }

  Map<String, dynamic> _buildBackupPayload() {
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
      'history': history.map((session) => session.toJson()).toList(),
    };
  }

  List<Schedule> _cloneSchedules(List<Schedule> source) {
    return source
        .map((schedule) => Schedule.fromJson(schedule.toJson()))
        .toList();
  }

  List<WorkoutSession> _cloneHistory(List<WorkoutSession> source) {
    return source
        .map((session) => WorkoutSession.fromJson(session.toJson()))
        .toList();
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;
      if (!pickedFile.name.toLowerCase().endsWith('.csv')) {
        await _showInfo('Seleziona un file CSV valido.');
        return;
      }

      final inputString = await _readPickedTextFile(pickedFile);
      final rows = _decodeCsv(inputString);

      int importedCount = 0;
      int skippedInvalidCount = 0;
      int skippedDuplicateCount = 0;

      for (final row in rows) {
        if (row.length < 7) {
          skippedInvalidCount++;
          continue;
        }

        final scheduleTitle = row[0].toString().trim();
        final week = int.tryParse(row[1].toString().trim());
        final exerciseName = row[2].toString().trim();
        final sets = int.tryParse(row[3].toString().trim());
        final reps = int.tryParse(row[4].toString().trim());
        final weight = double.tryParse(
          row[5].toString().trim().replaceAll(',', '.'),
        );
        final notes = row[6].toString().trim();

        if (scheduleTitle.isEmpty ||
            week == null ||
            exerciseName.isEmpty ||
            sets == null ||
            reps == null ||
            weight == null) {
          skippedInvalidCount++;
          continue;
        }

        final candidate = Exercise(
          name: exerciseName,
          set: sets,
          reps: reps,
          weight: weight,
          notes: notes,
          technique: IntensityTechnique.none,
        );

        final scheduleIndex = schedules.indexWhere(
          (s) => s.title == scheduleTitle && s.week == week,
        );
        final schedule = scheduleIndex != -1
            ? schedules[scheduleIndex]
            : Schedule(
                title: scheduleTitle,
                week: week,
                createdAt: DateTime.now(),
                exercises: [],
              );

        if (scheduleIndex == -1) {
          schedules.add(schedule);
        } else {
          schedule.isArchived = false;
        }

        if (_exerciseAlreadyExists(schedule, candidate)) {
          skippedDuplicateCount++;
          continue;
        }

        schedule.exercises.add(candidate);
        importedCount++;
      }

      _sortSchedules();
      setState(() {});
      await _saveSchedules();
      await _showInfo(
        'Importati $importedCount esercizi. Righe ignorate: $skippedInvalidCount. Duplicati saltati: $skippedDuplicateCount.',
      );
    } catch (e) {
      await _showInfo('Errore durante importazione: $e');
    }
  }

  Future<void> _exportSchedulesCsv() async {
    try {
      final csvText = _buildSchedulesCsv();
      if (csvText.isEmpty) {
        await _showInfo('Non ci sono schede da esportare in CSV.');
        return;
      }

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Esporta CSV',
        fileName: 'gymapp_schede.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csvText)),
      );

      if (savedPath == null && !kIsWeb) {
        return;
      }

      await _showInfo('CSV esportato con successo.');
    } catch (e) {
      await _showInfo('Errore durante export CSV: $e');
    }
  }

  Future<void> _exportBackupJson() async {
    try {
      final backupText = jsonEncode(_buildBackupPayload());
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Esporta backup',
        fileName: 'gymapp_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(backupText)),
      );

      if (savedPath == null && !kIsWeb) {
        return;
      }

      await _showInfo('Backup esportato con successo.');
    } catch (e) {
      await _showInfo('Errore durante export backup: $e');
    }
  }

  Future<void> _restoreBackupJson() async {
    try {
      final confirm =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ripristinare backup?'),
              content: const Text(
                'Questo sovrascriverà le schede e la cronologia attuali.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ripristina'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) {
        return;
      }

      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;
      if (!pickedFile.name.toLowerCase().endsWith('.json')) {
        await _showInfo('Seleziona un file JSON valido.');
        return;
      }

      final rawText = await _readPickedTextFile(pickedFile);
      final decoded = jsonDecode(_normalizeText(rawText));
      final previousSchedules = _cloneSchedules(schedules);
      final previousHistory = _cloneHistory(history);

      List<Schedule> restoredSchedules = [];
      List<WorkoutSession> restoredHistory = [];

      if (decoded is Map) {
        final backupMap = Map<String, dynamic>.from(decoded);
        restoredSchedules = (backupMap['schedules'] as List? ?? [])
            .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        restoredHistory = (backupMap['history'] as List? ?? [])
            .map(
              (e) =>
                  WorkoutSession.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } else if (decoded is List) {
        restoredSchedules = decoded
            .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        throw Exception('Formato backup non supportato.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        schedules
          ..clear()
          ..addAll(restoredSchedules);
        history
          ..clear()
          ..addAll(restoredHistory);
        _sortSchedules();
      });

      await _saveAllData();
      _showUndoSnackBar(
        message: 'Backup ripristinato.',
        onUndo: () {
          if (!mounted) {
            return;
          }

          setState(() {
            schedules
              ..clear()
              ..addAll(_cloneSchedules(previousSchedules));
            history
              ..clear()
              ..addAll(_cloneHistory(previousHistory));
            _sortSchedules();
          });
          _saveAllData();
        },
      );
    } catch (e) {
      await _showInfo('Errore durante ripristino backup: $e');
    }
  }

  void _deleteSchedule(int index) {
    if (index < 0 || index >= schedules.length) {
      return;
    }

    final deletedSchedule = schedules[index];
    setState(() {
      schedules.removeAt(index);
    });
    _saveSchedules();

    _showUndoSnackBar(
      message: 'Scheda eliminata.',
      onUndo: () {
        if (!mounted || schedules.contains(deletedSchedule)) {
          return;
        }

        setState(() {
          final restoreIndex = index > schedules.length
              ? schedules.length
              : index;
          schedules.insert(restoreIndex, deletedSchedule);
          _sortSchedules();
        });
        _saveSchedules();
      },
    );
  }

  void _addSchedule(String title, int week) {
    setState(() {
      schedules.add(
        Schedule(
          title: title,
          week: week,
          createdAt: DateTime.now(),
          exercises: [],
        ),
      );
      _sortSchedules();
    });
    _saveSchedules();
  }

  void _duplicateSchedule(Schedule schedule) {
    final copiedExercises = schedule.exercises
        .map(
          (exercise) => Exercise(
            name: exercise.name,
            set: exercise.set,
            reps: exercise.reps,
            weight: exercise.weight,
            notes: exercise.notes,
            technique: exercise.technique,
            backoffReps: exercise.backoffReps,
          ),
        )
        .toList();

    setState(() {
      schedules.add(
        Schedule(
          title: '${schedule.title} (copia)',
          week: schedule.week,
          createdAt: DateTime.now(),
          exercises: copiedExercises,
        ),
      );
      _sortSchedules();
    });
    _saveSchedules();
  }

  void _toggleArchiveSchedule(Schedule schedule) {
    setState(() {
      schedule.isArchived = !schedule.isArchived;
      _sortSchedules();
    });
    _saveSchedules();
  }

  List<int> _availableWeeks() {
    final weeks = schedules.map((schedule) => schedule.week).toSet().toList();
    weeks.sort();
    return weeks;
  }

  List<Schedule> _filteredSchedules() {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = schedules.where((schedule) {
      if (!_showArchived && schedule.isArchived) {
        return false;
      }

      if (_selectedWeekFilter != null && schedule.week != _selectedWeekFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final matchesTitle = schedule.title.toLowerCase().contains(query);
      final matchesExercise = schedule.exercises.any(
        (exercise) => exercise.name.toLowerCase().contains(query),
      );

      return matchesTitle || matchesExercise;
    }).toList();

    filtered.sort((a, b) {
      if (a.isArchived != b.isArchived) {
        return a.isArchived ? 1 : -1;
      }

      final weekCompare = a.week.compareTo(b.week);
      if (weekCompare != 0) {
        return weekCompare;
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return filtered;
  }

  void _showAddScheduleDialog() {
    final titleController = TextEditingController();
    final weekController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova Scheda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Titolo (es. Push Day)',
              ),
            ),
            TextField(
              controller: weekController,
              decoration: const InputDecoration(
                labelText: 'Settimana (numero)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  weekController.text.isNotEmpty) {
                _addSchedule(
                  titleController.text,
                  int.tryParse(weekController.text) ?? 1,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          defaultRestSeconds: _defaultRestSeconds,
          onDefaultRestSecondsChanged: _setDefaultRestSeconds,
          onExportBackup: _exportBackupJson,
          onRestoreBackup: _restoreBackupJson,
        ),
      ),
    );
  }

  Widget _buildSchedulesTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleSchedules = _filteredSchedules();
    final availableWeeks = _availableWeeks();
    final selectedWeekValue = availableWeeks.contains(_selectedWeekFilter)
        ? _selectedWeekFilter
        : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              labelText: 'Cerca schede o esercizi',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<int?>(
                  initialValue: selectedWeekValue,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Settimana'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tutte'),
                    ),
                    ...availableWeeks.map(
                      (week) => DropdownMenuItem<int?>(
                        value: week,
                        child: Text('Settimana $week'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedWeekFilter = value),
                ),
              ),
              FilterChip(
                label: const Text('Mostra archiviate'),
                selected: _showArchived,
                onSelected: (selected) =>
                    setState(() => _showArchived = selected),
              ),
              if (_searchQuery.isNotEmpty ||
                  _selectedWeekFilter != null ||
                  _showArchived)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedWeekFilter = null;
                      _showArchived = false;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset filtri'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${visibleSchedules.length} schede visibili',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visibleSchedules.isEmpty
              ? const Center(
                  child: Text('Nessuna scheda corrisponde ai filtri scelti.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: visibleSchedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final schedule = visibleSchedules[index];
                    final actualIndex = schedules.indexOf(schedule);

                    return Dismissible(
                      key: ValueKey(schedule.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        if (actualIndex != -1) {
                          _deleteSchedule(actualIndex);
                        }
                      },
                      background: Container(
                        color: colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete, color: colorScheme.onError),
                      ),
                      child: Card(
                        elevation: 2,
                        color: schedule.isArchived
                            ? colorScheme.surfaceContainerHighest
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: schedule.isArchived
                                ? colorScheme.surfaceContainer
                                : colorScheme.primaryContainer,
                            child: Icon(
                              schedule.isArchived
                                  ? Icons.archive
                                  : Icons.fitness_center,
                              color: schedule.isArchived
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            schedule.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: schedule.isArchived
                                  ? colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            'Settimana: ${schedule.week} • Esercizi: ${schedule.exercises.length}${schedule.isArchived ? ' • Archiviata' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Duplica',
                                icon: const Icon(Icons.copy),
                                onPressed: () => _duplicateSchedule(schedule),
                              ),
                              PopupMenuButton<_ScheduleMenuAction>(
                                tooltip: 'Azioni',
                                onSelected: (action) {
                                  switch (action) {
                                    case _ScheduleMenuAction.toggleArchive:
                                      _toggleArchiveSchedule(schedule);
                                      break;
                                    case _ScheduleMenuAction.delete:
                                      if (actualIndex != -1) {
                                        _deleteSchedule(actualIndex);
                                      }
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: _ScheduleMenuAction.toggleArchive,
                                    child: Text(
                                      schedule.isArchived
                                          ? 'Ripristina'
                                          : 'Archivia',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _ScheduleMenuAction.delete,
                                    child: Text('Elimina'),
                                  ),
                                ],
                              ),
                              const Icon(Icons.arrow_forward_ios),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScheduleDetailScreen(
                                  schedule: schedule,
                                  defaultRestSeconds: _defaultRestSeconds,
                                  onUpdate: () {
                                    setState(() {});
                                    _saveSchedules();
                                  },
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final colorScheme = Theme.of(context).colorScheme;

    if (history.isEmpty) {
      return const Center(child: Text('Ancora nessun allenamento completato.'));
    }

    final sortedHistory = List<WorkoutSession>.from(history)
      ..sort((a, b) => b.endTime.compareTo(a.endTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedHistory.length,
      itemBuilder: (context, index) {
        final session = sortedHistory[index];
        final duration = session.endTime.difference(session.startTime);
        final String durationStr = '${duration.inMinutes} min';

        int completedSets = 0;
        double totalVolume = 0;
        for (final ex in session.exercises) {
          for (final s in ex.sets) {
            if (s.isCompleted) {
              completedSets++;
              totalVolume += s.weight * s.reps;
            }
          }
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              session.scheduleTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${session.startTime.day}/${session.startTime.month}/${session.startTime.year} • $durationStr\nVolume: ${totalVolume.toStringAsFixed(1)} kg • Set fatti: $completedSets',
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: colorScheme.error),
              onPressed: () => _deleteHistory(history.indexOf(session)),
            ),
            children: session.exercises.map((ex) {
              return ListTile(
                title: Text(ex.name),
                subtitle: Text(
                  ex.sets
                      .where((s) => s.isCompleted)
                      .map((s) => '${s.weight}kg x ${s.reps}')
                      .join(', '),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/app_icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text('GymApp', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Impostazioni',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          if (_currentIndex == 0)
            PopupMenuButton<_HomeAction>(
              tooltip: 'Importa ed esporta',
              onSelected: (action) {
                switch (action) {
                  case _HomeAction.importCsv:
                    _importCsv();
                    break;
                  case _HomeAction.exportCsv:
                    _exportSchedulesCsv();
                    break;
                  case _HomeAction.exportBackup:
                    _exportBackupJson();
                    break;
                  case _HomeAction.restoreBackup:
                    _restoreBackupJson();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _HomeAction.importCsv,
                  child: ListTile(
                    leading: Icon(Icons.file_upload),
                    title: Text('Importa CSV'),
                  ),
                ),
                PopupMenuItem(
                  value: _HomeAction.exportCsv,
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Esporta CSV'),
                  ),
                ),
                PopupMenuItem(
                  value: _HomeAction.exportBackup,
                  child: ListTile(
                    leading: Icon(Icons.backup),
                    title: Text('Esporta backup'),
                  ),
                ),
                PopupMenuItem(
                  value: _HomeAction.restoreBackup,
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Ripristina backup'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _currentIndex == 0
          ? _buildSchedulesTab()
          : _currentIndex == 1
          ? _buildHistoryTab()
          : StatsScreen(history: history),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddScheduleDialog,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Schede'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Cronologia',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistiche',
          ),
        ],
      ),
    );
  }
}
