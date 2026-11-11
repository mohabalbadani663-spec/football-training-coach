import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/tenant_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'exercise_detail_screen.dart';
import 'training_mode_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final TrainingSession session;
  final TrainingRepository repository;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late List<Exercise> exercises;
  late int duration;
  late DateTime scheduledFor;
  late Future<List<TeamInfo>> teamsFuture;
  late final TextEditingController titleController;
  late final TextEditingController objectiveController;
  late final TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    exercises = [...widget.session.exercises];
    duration = widget.session.duration;
    scheduledFor = widget.session.date;
    teamsFuture = widget.repository.fetchCoachTeams();
    titleController = TextEditingController(text: widget.session.title);
    objectiveController = TextEditingController(text: widget.session.objective);
    notesController = TextEditingController(text: widget.session.notes);
  }

  @override
  void dispose() {
    titleController.dispose();
    objectiveController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('تفاصيل الحصة'),
        actions: [
          IconButton(
            onPressed: _saveChanges,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 3, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const TagPill(
                      label: 'مسودة قابلة للتعديل',
                      icon: Icons.edit_note_rounded,
                    ),
                    const Spacer(),
                    Text(
                      '$duration دقيقة',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  widget.session.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 7),
                Text(
                  '${widget.session.team}  •  ${widget.session.objective}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'الموعد: ${_formatDate(widget.session.date)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (widget.session.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(widget.session.notes, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        icon: Icons.layers_outlined,
                        value: '${exercises.length}',
                        label: 'تمارين',
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: _TeamPlayerSummary(repository: widget.repository, teamId: widget.session.teamId)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Summary(
                        icon: Icons.timer_outlined,
                        value: '$duration',
                        label: 'دقيقة',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SessionMetadataEditor(
            titleController: titleController,
            objectiveController: objectiveController,
            notesController: notesController,
            scheduledFor: scheduledFor,
            teamsFuture: teamsFuture,
            selectedTeamId: widget.session.teamId,
            onTeamChanged: (team) {
              setState(() {
                widget.session.teamId = team.id;
                widget.session.team = team.name;
              });
            },
            onDateChanged: (date) => setState(() => scheduledFor = date),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'محتوى الحصة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddExercise,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...exercises.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EditableExercise(
                index: entry.key,
                exercise: entry.value,
                onDelete: () => setState(() => exercises.removeAt(entry.key)),
                onMoveUp: entry.key == 0
                    ? null
                    : () => setState(() {
                        final item = exercises.removeAt(entry.key);
                        exercises.insert(entry.key - 1, item);
                      }),
                onMoveDown: entry.key == exercises.length - 1
                    ? null
                    : () => setState(() {
                        final item = exercises.removeAt(entry.key);
                        exercises.insert(entry.key + 1, item);
                      }),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ExerciseDetailScreen(exercise: entry.value),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'تغيير مدة الحصة',
            icon: Icons.timer_outlined,
            onPressed: _changeDuration,
            expand: true,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'بدء التدريب',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              widget.session.exercises = exercises;
              widget.session.duration = duration;
              Navigator.of(context).push(
                MaterialPageRoute(
                          builder: (_) => TrainingModeScreen(session: widget.session, repository: widget.repository),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    widget.session.title = titleController.text.trim().isEmpty ? widget.session.title : titleController.text.trim();
    widget.session.objective = objectiveController.text.trim();
    widget.session.notes = notesController.text.trim();
    widget.session.date = scheduledFor;
    widget.session.exercises = exercises;
    widget.session.duration = duration;
    try {
      await widget.repository.saveSession(
        coachId: widget.repository.currentUserId ?? '',
        teamId: widget.session.teamId,
        session: widget.session,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ تعديلات الحصة')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التعديلات. حاول مرة أخرى.')),
      );
    }
  }

  String _formatDate(DateTime value) {
    final date = '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date  •  $time';
  }

  void _changeDuration() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مدة الحصة', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 15),
              Wrap(
                spacing: 9,
                children: [60, 75, 90, 120]
                    .map(
                      (value) => ActionChip(
                        label: Text('$value دقيقة'),
                        onPressed: () {
                          setState(() => duration = value);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddExercise() {
    final exercisesFuture = widget.repository.fetchExercises();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'إضافة تمرين',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Exercise>>(
              future: exercisesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const EmptyState(
                    title: 'تعذر تحميل التمارين',
                    description: 'تحقق من الاتصال ثم حاول مرة أخرى.',
                    icon: Icons.cloud_off_rounded,
                  );
                }
                return Column(
                  children: snapshot.data!
                      .map(
                        (exercise) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ExerciseCard(
                            exercise: exercise,
                            compact: true,
                            onTap: () {
                              setState(() => exercises.add(exercise));
                              Navigator.pop(sheetContext);
                            },
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionMetadataEditor extends StatelessWidget {
  const _SessionMetadataEditor({
    required this.titleController,
    required this.objectiveController,
    required this.notesController,
    required this.scheduledFor,
    required this.teamsFuture,
    required this.selectedTeamId,
    required this.onTeamChanged,
    required this.onDateChanged,
  });

  final TextEditingController titleController;
  final TextEditingController objectiveController;
  final TextEditingController notesController;
  final DateTime scheduledFor;
  final Future<List<TeamInfo>> teamsFuture;
  final String? selectedTeamId;
  final ValueChanged<TeamInfo> onTeamChanged;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('بيانات الحصة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'عنوان الحصة'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objectiveController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'الهدف'),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<TeamInfo>>(
              future: teamsFuture,
              builder: (context, snapshot) {
                final teams = snapshot.data ?? const <TeamInfo>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (teams.isEmpty) return const SizedBox.shrink();
                final value = teams.any((team) => team.id == selectedTeamId) ? selectedTeamId : null;
                return DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(labelText: 'الفريق'),
                  items: teams.map((team) => DropdownMenuItem(value: team.id, child: Text(team.name))).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    onTeamChanged(teams.firstWhere((team) => team.id == id));
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickDateTime(context),
              icon: const Icon(Icons.event_outlined),
              label: Text('الموعد: ${_formatDateTime(scheduledFor)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'ملاحظات المدرب', alignLabelWithHint: true),
            ),
          ],
        ),
      );

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledFor,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(scheduledFor));
    if (time == null) return;
    onDateChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _formatDateTime(DateTime value) {
    final date = '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date  •  $time';
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.muted, size: 17),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _TeamPlayerSummary extends StatelessWidget {
  const _TeamPlayerSummary({required this.repository, required this.teamId});

  final TrainingRepository repository;
  final String? teamId;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Player>>(
        future: teamId == null ? Future.value(const <Player>[]) : repository.fetchTeamPlayers(teamId!),
        builder: (context, snapshot) => _Summary(
          icon: Icons.people_outline,
          value: snapshot.connectionState == ConnectionState.waiting ? '…' : '${snapshot.data?.length ?? 0}',
          label: 'لاعبًا',
        ),
      );
}

class _EditableExercise extends StatelessWidget {
  const _EditableExercise({
    required this.index,
    required this.exercise,
    required this.onDelete,
    required this.onTap,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final Exercise exercise;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(17),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ExerciseVisual(exercise: exercise, size: 55),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.duration} دقيقة  •  ${exercise.category.label}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onMoveUp,
                icon: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onMoveDown,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
