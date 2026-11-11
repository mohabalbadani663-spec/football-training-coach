import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/tenant_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CoachHomeScreen extends StatelessWidget {
  const CoachHomeScreen({
    super.key,
    required this.repository,
    required this.userName,
    required this.onCreateSession,
    required this.onExercises,
    required this.onPlans,
    required this.onTeam,
    required this.onStartSession,
  });

  final TrainingRepository repository;
  final String userName;
  final VoidCallback onCreateSession;
  final VoidCallback onExercises;
  final VoidCallback onPlans;
  final VoidCallback onTeam;
  final ValueChanged<TrainingSession> onStartSession;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Greeting(userName: userName),
        const SizedBox(height: 22),
        _TodaySessionFromRepository(
          repository: repository,
          onStart: onStartSession,
        ),
        const SizedBox(height: 26),
        SectionHeader(title: 'إجراءات سريعة'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.auto_awesome_rounded,
                label: 'إنشاء حصة',
                color: AppColors.primary,
                onTap: onCreateSession,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.menu_book_rounded,
                label: 'التمارين',
                color: AppColors.info,
                onTap: onExercises,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.calendar_month_rounded,
                label: 'الخطة',
                color: AppColors.warning,
                onTap: onPlans,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        SectionHeader(
          title: 'نظرة على الفريق',
          action: 'عرض الفريق',
          onAction: onTeam,
        ),
        const SizedBox(height: 12),
        _TeamOverview(repository: repository),
        const SizedBox(height: 26),
        SectionHeader(
          title: 'الحصص الأخيرة',
          action: 'السجل',
          onAction: onPlans,
        ),
        const SizedBox(height: 12),
        _RecentSessions(repository: repository, onTap: onStartSession),
      ],
    );
  }
}

class _TeamOverview extends StatelessWidget {
  const _TeamOverview({required this.repository});
  final TrainingRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeamInfo>>(
      future: repository.fetchCoachTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()));
        }
        final teams = snapshot.data ?? const <TeamInfo>[];
        if (teams.isEmpty) {
          return const EmptyState(title: 'لم يتم إعداد فريق بعد', description: 'أنشئ فريقًا من صفحة فريقي.', icon: Icons.groups_outlined);
        }
        final team = teams.first;
        return Row(
          children: [
            Expanded(child: MiniStat(value: '${team.memberCount}', label: 'لاعبًا', icon: Icons.groups_rounded)),
            const SizedBox(width: 10),
            Expanded(child: MiniStat(value: team.ageGroup ?? '-', label: 'الفئة العمرية', icon: Icons.shield_outlined, color: AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: MiniStat(value: team.level ?? '-', label: 'المستوى', icon: Icons.trending_up_rounded, color: AppColors.warning)),
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مساء الخير،',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: Theme.of(context).textTheme.displayLarge,
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}

class _TodaySessionFromRepository extends StatefulWidget {
  const _TodaySessionFromRepository({
    required this.repository,
    required this.onStart,
  });

  final TrainingRepository repository;
  final ValueChanged<TrainingSession> onStart;

  @override
  State<_TodaySessionFromRepository> createState() => _TodaySessionFromRepositoryState();
}

class _TodaySessionFromRepositoryState extends State<_TodaySessionFromRepository> {
  late final Future<List<TrainingSession>> future;

  @override
  void initState() {
    super.initState();
    future = widget.repository.fetchCoachSessions(widget.repository.currentUserId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrainingSession>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final sessions = snapshot.data ?? const <TrainingSession>[];
        if (snapshot.hasError || sessions.isEmpty) {
          return const EmptyState(
            title: 'لا توجد حصة اليوم',
            description: 'أنشئ أول حصة تدريبية لتظهر هنا.',
            icon: Icons.event_note_outlined,
          );
        }
        final now = DateTime.now();
        final upcoming = sessions.where((s) => !s.date.isBefore(now)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final session = upcoming.isNotEmpty ? upcoming.first : sessions.first;
        return _TodaySessionCard(
          session: session,
          onStart: () => widget.onStart(session),
        );
      },
    );
  }
}

class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({required this.session, required this.onStart});
  final TrainingSession session;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.26)),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF203220), Color(0xFF121916)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TagPill(label: 'حصة اليوم', icon: Icons.today_rounded),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            session.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            session.objective,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SessionMeta(
                icon: Icons.groups_outlined,
                label: session.team.isEmpty ? 'الفريق' : session.team,
              ),
              const SizedBox(width: 18),
              _SessionMeta(icon: Icons.timer_outlined, label: '${session.duration} دقيقة'),
              const SizedBox(width: 18),
              _SessionMeta(
                icon: Icons.people_outline,
                label: '${session.exercises.length} تمارين',
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'بدء الحصة',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _SessionMeta extends StatelessWidget {
  const _SessionMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessions extends StatefulWidget {
  const _RecentSessions({required this.repository, required this.onTap});

  final TrainingRepository repository;
  final ValueChanged<TrainingSession> onTap;

  @override
  State<_RecentSessions> createState() => _RecentSessionsState();
}

class _RecentSessionsState extends State<_RecentSessions> {
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const EmptyState(
            title: 'لا توجد حصص بعد',
            description: 'أنشئ أول حصة تدريبية لفريقك.',
            icon: Icons.event_note_outlined,
          );
        }
        return Column(
          children: snapshot.data!
              .map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentSessionCard(
                    session: session,
                    onTap: () => widget.onTap(session),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session, required this.onTap});
  final TrainingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.sports_soccer_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.team}  •  ${session.duration} دقيقة',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}
