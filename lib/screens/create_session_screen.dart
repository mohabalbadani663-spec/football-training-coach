import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/tenant_models.dart';
import '../services/data_repository.dart';
import '../services/session_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({
    super.key,
    required this.onSave,
    required this.repository,
  });

  final ValueChanged<TrainingSession> onSave;
  final TrainingRepository repository;

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  int step = 0;
  bool saving = false;
  String objective = 'التمرير والاستلام';
  String level = 'متوسط';
  int duration = 90;
  String space = 'نصف ملعب';
  final selectedEquipment = <String>{'كرات', 'أقماع'};
  late Future<List<TeamInfo>> teamsFuture;
  String? selectedTeamId;
  String selectedTeamName = 'الفريق الأول';
  DateTime scheduledFor = DateTime.now().add(const Duration(hours: 1));
  final titleController = TextEditingController();
  final notesController = TextEditingController();

  final objectives = [
    'التمرير والاستلام',
    'السيطرة على الكرة',
    'السرعة والرشاقة',
    'الإنهاء',
    'اتخاذ القرار',
  ];
  final spaces = ['مساحة صغيرة', 'ربع ملعب', 'نصف ملعب', 'ملعب كامل'];
  final equipment = ['كرات', 'أقماع', 'مرميان', 'صدريات', 'سلم رشاقة', 'عصي'];

  @override
  void initState() {
    super.initState();
    teamsFuture = widget.repository.fetchCoachTeams();
    titleController.text = objective;
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('إنشاء حصة جديدة'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 18),
            child: Center(
              child: Text(
                '${step + 1}/4',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: index <= step
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
              children: [_buildStep()],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (step > 0) ...[
                  Expanded(
                    child: SecondaryButton(
                      label: 'السابق',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => setState(() => step--),
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: PrimaryButton(
                    label: saving
                        ? 'جارٍ الإنشاء...'
                        : step == 3
                        ? 'إنشاء الحصة'
                        : 'التالي',
                    icon: step == 3
                        ? Icons.auto_awesome_rounded
                        : Icons.arrow_back_rounded,
                    onPressed: saving ? null : _next,
                    expand: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (step) {
      case 0:
        return _ChoiceStep(
          title: 'ما هدف الحصة اليوم؟',
          subtitle: 'اختر الهدف الرئيسي الذي تريد أن يتطور فيه فريقك.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'عنوان الحصة',
                  hintText: 'مثال: التمرير تحت الضغط',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Text('الهدف الرئيسي', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: objectives
                    .map(
                      (value) => _Option(
                        label: value,
                        selected: objective == value,
                        onTap: () => setState(() => objective = value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      case 1:
        return _ChoiceStep(
          title: 'من هو الفريق؟',
          subtitle: 'سنستخدم بيانات الفريق لتحديد التمارين المناسبة.',
          child: FutureBuilder<List<TeamInfo>>(
            future: teamsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return const EmptyState(title: 'لا يوجد فريق', description: 'أنشئ فريقًا في صفحة فريقي أولًا.', icon: Icons.groups_outlined);
              }
              final teams = snapshot.data!;
              selectedTeamId ??= teams.first.id;
              selectedTeamName = teams.firstWhere((t) => t.id == selectedTeamId).name;
              return Column(
                children: [
                  ...teams.map((team) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TeamOption(
                      name: team.name,
                      meta: '${team.memberCount} لاعبًا  •  ${team.level ?? 'غير محدد'}',
                      selected: selectedTeamId == team.id,
                      onTap: () => setState(() { selectedTeamId = team.id; selectedTeamName = team.name; }),
                    ),
                  )),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'مستوى الفريق'),
                    items: ['مبتدئ', 'متوسط', 'متقدم'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setState(() => level = value ?? level),
                  ),
                ],
              );
            },
          ),
        );
      case 2:
        return _ChoiceStep(
          title: 'كم وقت التدريب؟',
          subtitle: 'سيتم توزيع زمن الحصة تلقائيًا على مراحلها.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [60, 75, 90, 120]
                    .map(
                      (value) => _Option(
                        label: '$value دقيقة',
                        selected: duration == value,
                        onTap: () => setState(() => duration = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text('موعد الحصة', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.event_outlined),
                label: Text(_formatDateTime(scheduledFor)),
              ),
            ],
          ),
        );
      default:
        return _ChoiceStep(
          title: 'المساحة والمعدات',
          subtitle: 'حدد الموارد المتاحة في الملعب اليوم.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المساحة', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: spaces
                    .map(
                      (value) => _Option(
                        label: value,
                        selected: space == value,
                        onTap: () => setState(() => space = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'المعدات المتوفرة',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: equipment
                    .map(
                      (value) => _Option(
                        label: value,
                        selected: selectedEquipment.contains(value),
                        onTap: () => setState(() {
                          if (selectedEquipment.contains(value)) {
                            selectedEquipment.remove(value);
                          } else {
                            selectedEquipment.add(value);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: notesController,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات المدرب',
                  hintText: 'أضف تعليمات أو ملاحظات للحصة...',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _next() async {
    if (step < 3) {
      setState(() => step++);
      return;
    }

    setState(() => saving = true);
    try {
      final exercises = await widget.repository.fetchExercises();
      final selected = const SessionGenerator().generate(
        exercises: exercises,
        request: SessionGeneratorRequest(
          objective: objective,
          level: level,
          duration: duration,
          space: space,
          equipment: selectedEquipment,
        ),
      );
      final session = TrainingSession(
        id: _uuidFromNow(),
        title: titleController.text.trim().isEmpty ? objective : titleController.text.trim(),
        team: selectedTeamName,
        objective: objective,
        duration: duration,
        date: scheduledFor,
        exercises: selected,
        notes: notesController.text.trim(),
      );
      await widget.repository.saveSession(
        coachId: widget.repository.currentUserId ?? '',
        teamId: selectedTeamId,
        session: session,
      );
      if (!mounted) return;
      widget.onSave(session);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الحصة. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _uuidFromNow() {
    final value = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(32, '0');
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20, 32)}';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledFor,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledFor),
    );
    if (time == null) return;
    setState(() {
      scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatDateTime(DateTime value) {
    final date = '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date  •  $time';
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 27),
      child,
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.13)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          if (selected) const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TeamOption extends StatelessWidget {
  const _TeamOption({
    required this.name,
    required this.meta,
    required this.selected,
    this.onTap,
  });

  final String name;
  final String meta;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(17),
    child: Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: selected ? AppColors.primary : AppColors.border,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surfaceAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.shield_outlined,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(meta, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        if (selected)
          const Icon(Icons.check_circle_rounded, color: AppColors.primary),
      ],
    ),
    ),
  );
}
