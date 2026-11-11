import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'session_detail_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    required this.onCreateSession,
    required this.repository,
  });
  final VoidCallback onCreateSession;
  final TrainingRepository repository;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              tabs: const [
                Tab(text: 'الخطة الأسبوعية'),
                Tab(text: 'السجل التدريبي'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _WeeklyPlan(
                onCreateSession: widget.onCreateSession,
                repository: widget.repository,
              ),
              _History(repository: widget.repository),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyPlan extends StatefulWidget {
  const _WeeklyPlan({required this.onCreateSession, required this.repository});
  final VoidCallback onCreateSession;
  final TrainingRepository repository;

  @override
  State<_WeeklyPlan> createState() => _WeeklyPlanState();
}

class _WeeklyPlanState extends State<_WeeklyPlan> {
  late DateTime _weekStart;
  late Future<List<TrainingSession>> _future;
  late Future<List<WeeklyPlan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _reload();
    _reloadPlans();
  }

  void _reload() {
    _future = widget.repository.fetchCoachSessions(widget.repository.currentUserId ?? '');
  }

  void _reloadPlans() => _plansFuture = _loadPlans();

  Future<List<WeeklyPlan>> _loadPlans() async {
    final teams = await widget.repository.fetchCoachTeams();
    if (teams.isEmpty) return const [];
    return widget.repository.fetchWeeklyPlans(teamId: teams.first.id, weekStart: _weekStart);
  }

  static DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final daysSinceSunday = day.weekday % 7;
    return day.subtract(Duration(days: daysSinceSunday));
  }

  DateTime _endOfWeek(DateTime start) => start.add(const Duration(days: 7));

  String _dateRange() {
    final end = _endOfWeek(_weekStart).subtract(const Duration(days: 1));
    return '${_weekStart.day} ${_month(_weekStart.month)} – ${end.day} ${_month(end.month)} ${end.year}';
  }

  String _month(int month) => const [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
      ][month];

  Future<void> _addPlan() async => _openPlanEditor();

  Future<void> _editPlan(WeeklyPlan plan) async => _openPlanEditor(plan);

  Future<void> _deletePlan(WeeklyPlan plan) async {
    await widget.repository.deleteWeeklyPlan(plan.id);
    if (mounted) setState(_reloadPlans);
  }

  Future<void> _openPlanEditor([WeeklyPlan? existing]) async {
    final teams = await widget.repository.fetchCoachTeams();
    if (!mounted || teams.isEmpty) return;
    final title = TextEditingController(text: existing?.title ?? '');
    final objective = TextEditingController(text: existing?.objective ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    var dayIndex = existing?.dayIndex ?? 0;
    var teamId = existing?.teamId ?? teams.first.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة خطة أسبوعية' : 'تعديل الخطة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الخطة')),
                TextField(controller: objective, decoration: const InputDecoration(labelText: 'الهدف')),
                DropdownButtonFormField<String>(
                  value: teamId,
                  decoration: const InputDecoration(labelText: 'الفريق'),
                  items: teams.map((team) => DropdownMenuItem(value: team.id, child: Text(team.name))).toList(),
                  onChanged: (value) => setDialogState(() => teamId = value ?? teamId),
                ),
                DropdownButtonFormField<int>(
                  value: dayIndex,
                  decoration: const InputDecoration(labelText: 'اليوم'),
                  items: const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'].asMap().entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setDialogState(() => dayIndex = value ?? dayIndex),
                ),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (result == true && title.text.trim().isNotEmpty) {
      final plan = WeeklyPlan(
        id: existing?.id ?? _newPlanId(),
        teamId: teamId,
        weekStart: _weekStart,
        dayIndex: dayIndex,
        title: title.text.trim(),
        objective: objective.text.trim(),
        notes: notes.text.trim(),
      );
      await widget.repository.saveWeeklyPlan(plan);
      if (mounted) setState(_reloadPlans);
    }
    title.dispose(); objective.dispose(); notes.dispose();
  }

  String _newPlanId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0').substring(0, 8)}-0000-4000-8000-${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0').substring(8, 20)}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrainingSession>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            title: 'تعذر تحميل الخطة',
            description: 'تحقق من اتصال Supabase ثم حاول مرة أخرى.',
            icon: Icons.cloud_off_rounded,
          );
        }
        final sessions = snapshot.data ?? const <TrainingSession>[];
        final byDay = <int, TrainingSession>{};
        for (final session in sessions) {
          final date = DateTime(session.date.year, session.date.month, session.date.day);
          if (!date.isBefore(_weekStart) && date.isBefore(_endOfWeek(_weekStart))) {
            byDay[date.difference(_weekStart).inDays] = session;
          }
        }
        const names = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('هذا الأسبوع', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 5),
                      Text(_dateRange(), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'الأسبوع السابق',
                  onPressed: () => setState(() { _weekStart = _weekStart.subtract(const Duration(days: 7)); _reload(); _reloadPlans(); }),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                IconButton(
                  tooltip: 'الأسبوع التالي',
                  onPressed: () => setState(() { _weekStart = _weekStart.add(const Duration(days: 7)); _reload(); _reloadPlans(); }),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FutureBuilder<List<WeeklyPlan>>(
              future: _plansFuture,
              builder: (context, snapshot) {
                final plans = snapshot.data ?? const <WeeklyPlan>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('خطط الأيام', style: Theme.of(context).textTheme.titleLarge)),
                        TextButton.icon(onPressed: _addPlan, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('إضافة خطة')),
                      ],
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator()
                    else if (plans.isEmpty)
                      const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('لا توجد خطط مستقلة لهذا الأسبوع بعد.'))
                    else
                      ...plans.map((plan) => _WeeklyPlanCard(plan: plan, onEdit: () => _editPlan(plan), onDelete: () => _deletePlan(plan))),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            ...List.generate(7, (index) {
              final session = byDay[index];
              final date = _weekStart.add(Duration(days: index));
              return _DayPlan(
                name: names[index],
                date: date,
                session: session,
                onTap: session == null ? widget.onCreateSession : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session, repository: widget.repository))),
              );
            }),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'إضافة حصة إلى الخطة',
              icon: Icons.add_rounded,
              onPressed: widget.onCreateSession,
              expand: true,
            ),
          ],
        );
      },
    );
  }
}

class _WeeklyPlanCard extends StatelessWidget {
  const _WeeklyPlanCard({required this.plan, required this.onEdit, required this.onDelete});
  final WeeklyPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(child: Text('${plan.dayIndex + 1}')),
          title: Text(plan.title),
          subtitle: Text(plan.objective.isEmpty ? 'بدون هدف محدد' : plan.objective),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ),
      );
}

class _DayPlan extends StatelessWidget {
  const _DayPlan({required this.name, required this.date, required this.session, required this.onTap});
  final String name;
  final DateTime date;
  final TrainingSession? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSession = session != null;
    final color = hasSession ? AppColors.primary : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: hasSession ? AppColors.surface : AppColors.background,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.border.withValues(alpha: hasSession ? 1 : .55)),
          ),
          child: Row(
            children: [
              SizedBox(width: 64, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(color: hasSession ? AppColors.foreground : AppColors.muted, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${date.day}/${date.month}', style: Theme.of(context).textTheme.labelSmall),
              ])),
              Container(width: 3, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 13),
              Expanded(child: hasSession
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(session!.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${session!.duration} دقيقة  •  ${session!.objective}', style: Theme.of(context).textTheme.labelSmall),
                    ])
                  : Text('لا توجد حصة مجدولة', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
              Icon(hasSession ? Icons.event_note_rounded : Icons.add_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _History extends StatefulWidget {
  const _History({required this.repository});

  final TrainingRepository repository;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  late final Future<List<TrainingSession>> sessionsFuture;

  @override
  void initState() {
    super.initState();
    sessionsFuture = widget.repository.fetchCoachSessions(widget.repository.currentUserId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrainingSession>>(
      future: sessionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const EmptyState(
            title: 'لا يوجد سجل بعد',
            description: 'ستظهر الحصص هنا بعد حفظها أو إكمالها.',
            icon: Icons.history_rounded,
          );
        }
        final sessions = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) => _HistoryCard(
            session: sessions[index],
            repository: widget.repository,
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session, required this.repository});
  final TrainingSession session;
  final TrainingRepository repository;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              SessionDetailScreen(session: session, repository: repository),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagPill(label: 'مكتملة', icon: Icons.check_rounded),
                const Spacer(),
                Text(
                  _date(session.date),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(session.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              '${session.team}  •  ${session.duration} دقيقة  •  ${session.exercises.length} تمارين',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (session.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                session.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) => '${date.day} أغسطس';
}
