import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'exercise_detail_screen.dart';
import 'training_mode_screen.dart';

class PlayerHomeScreen extends StatelessWidget {
  const PlayerHomeScreen({
    super.key,
    required this.repository,
    required this.onTrain,
    required this.onProgress,
    required this.onChallenges,
    required this.userName,
  });

  final TrainingRepository repository;
  final VoidCallback onTrain;
  final VoidCallback onProgress;
  final VoidCallback onChallenges;
  final String userName;

  Future<(List<TrainingSession>, List<PlayerProgress>, List<Exercise>)> _load() async {
    final sessions = await repository.fetchPlayerSessions(repository.currentUserId ?? '');
    final progress = await repository.fetchPlayerProgress(repository.currentUserId ?? '');
    final exercises = await repository.fetchExercises();
    return (sessions, progress, exercises);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<TrainingSession>, List<PlayerProgress>, List<Exercise>)>(
      future: _load(),
      builder: (context, snapshot) {
        final sessions = snapshot.data?.$1 ?? const <TrainingSession>[];
        final progress = snapshot.data?.$2 ?? const <PlayerProgress>[];
        final exercises = snapshot.data?.$3 ?? const <Exercise>[];
        final average = progress.isEmpty
            ? null
            : progress.map((e) => e.progress).reduce((a, b) => a + b) / progress.length;
        final now = DateTime.now();
        final upcoming = sessions.where((s) => !s.date.isBefore(now)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final nextSession = upcoming.isNotEmpty ? upcoming.first : (sessions.isEmpty ? null : sessions.first);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('جاهز لجولتك القادمة؟', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text('أهلًا يا $userName', style: Theme.of(context).textTheme.displayLarge),
                    ],
                  ),
                ),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.notifications_none_rounded, color: AppColors.foreground),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if (nextSession != null)
              _TrainingChoice(
                title: 'حصة فريقك القادمة',
                subtitle: nextSession.title,
                meta: '${nextSession.duration} دقيقة  •  ${nextSession.objective}',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                onTap: onTrain,
              )
            else
              _PlayerTodayCard(
                exercise: exercises.isEmpty ? null : exercises.first,
                onStart: onTrain,
              ),
            const SizedBox(height: 24),
            if (average != null)
              InkWell(
                onTap: onProgress,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      SizedBox(width: 68, height: 68, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: average / 100, strokeWidth: 7, backgroundColor: AppColors.border), Text('${average.round()}%', style: const TextStyle(fontWeight: FontWeight.w800))])),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تقدمك الحالي', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 5), Text('تابع تطور مهاراتك من صفحة التقدم.', style: Theme.of(context).textTheme.bodyMedium)])),
                      const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            if (average != null) const SizedBox(height: 24),
            SectionHeader(title: 'تدريب منزلي', action: 'تدرّب', onAction: onTrain),
            const SizedBox(height: 12),
            _TrainingChoice(title: 'إتقان الكرة في المنزل', subtitle: 'تدريب فردي', meta: '12 دقيقة  •  مساحة صغيرة', icon: Icons.home_outlined, color: AppColors.info, onTap: onTrain),
            const SizedBox(height: 24),
            SectionHeader(title: 'التحديات', action: 'عرض الكل', onAction: onChallenges),
            const SizedBox(height: 12),
            InkWell(
              onTap: onChallenges,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: const Row(children: [Icon(Icons.emoji_events_outlined, color: AppColors.warning), SizedBox(width: 12), Expanded(child: Text('اكتشف التحديات المتاحة لك')), Icon(Icons.chevron_left_rounded, color: AppColors.muted)]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerTodayCard extends StatelessWidget {
  const _PlayerTodayCard({required this.exercise, required this.onStart});

  final Exercise? exercise;

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF284421), Color(0xFF121916)],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TagPill(label: 'تدريب اليوم', icon: Icons.today_rounded),
              const Spacer(),
              Text(
                exercise == null ? 'تدريب فردي' : '${exercise!.duration} دقيقة',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            exercise?.name ?? 'تدريب فردي بالكرة',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 7),
          Text(
            exercise?.description.isNotEmpty == true ? exercise!.description : 'اختر تمرينًا من مكتبة التدريبات وابدأ جلسة فردية.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'ابدأ التدريب',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(value: value, color: color, height: 7),
      ],
    );
  }
}

class PlayerTrainingScreen extends StatelessWidget {
  const PlayerTrainingScreen({super.key, required this.repository});

  final TrainingRepository repository;

  Future<(List<Exercise>, List<TrainingSession>)> _load() async {
    final exercises = await repository.fetchExercises();
    final sessions = await repository.fetchPlayerSessions(repository.currentUserId ?? '');
    return (exercises, sessions);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Exercise>, List<TrainingSession>)>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.$1.isEmpty) {
          return const EmptyState(
            title: 'تعذر تحميل تدريباتك',
            description: 'تحقق من الاتصال ثم حاول مرة أخرى.',
            icon: Icons.cloud_off_rounded,
          );
        }
        final exercises = snapshot.data!.$1;
        final assignedSessions = snapshot.data!.$2;
        final now = DateTime.now();
        final upcoming = assignedSessions.where((s) => !s.date.isBefore(now)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final assigned = upcoming.isNotEmpty ? upcoming.first : (assignedSessions.isEmpty ? null : assignedSessions.first);
        final homeExercise = exercises.firstWhere(
          (exercise) => exercise.nameEn == 'Home Ball Mastery',
          orElse: () => exercises.last,
        );
        final suggestedExercise = exercises.first;
        final trainingExercises = exercises.take(2).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Text('تدرّب بذكاء', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 7),
            Text('اختر الجلسة التي تناسب هدفك ووقتك اليوم.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 23),
            if (assigned != null)
              _TrainingChoice(
                title: 'حصة فريقك',
                subtitle: assigned.title,
                meta: '${assigned.duration} دقيقة  •  ${assigned.objective}',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingModeScreen(session: assigned, repository: widget.repository))),
              )
            else
              _TrainingChoice(
                title: 'تدريب فردي',
                subtitle: 'مراوغة وتحكم بالكرة',
                meta: '25 دقيقة  •  متوسط',
                icon: Icons.today_rounded,
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingModeScreen(session: TrainingSession(id: 'player-today', title: 'تدريب فردي', team: 'تدريب فردي', objective: 'المهارات الفنية', duration: 25, date: DateTime.now(), exercises: trainingExercises), repository: widget.repository))),
              ),
            const SizedBox(height: 12),
            _TrainingChoice(
              title: 'تدريب منزلي',
              subtitle: 'إتقان الكرة في المنزل',
              meta: '12 دقيقة  •  مساحة صغيرة',
              icon: Icons.home_outlined,
              color: AppColors.info,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: homeExercise))),
            ),
            const SizedBox(height: 25),
            const SectionHeader(title: 'مقترح لك'),
            const SizedBox(height: 12),
            ExerciseCard(
              exercise: suggestedExercise,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: suggestedExercise))),
            ),
          ],
        );
      },
    );
  }
}

class _TrainingChoice extends StatelessWidget {
  const _TrainingChoice({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(meta, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class PlayerProgressScreen extends StatelessWidget {
  const PlayerProgressScreen({super.key, required this.repository});

  final TrainingRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlayerProgress>>(
      future: repository.fetchPlayerProgress(repository.currentUserId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            title: 'تعذر تحميل التقدم',
            description: 'تحقق من الاتصال ثم حاول مرة أخرى.',
            icon: Icons.cloud_off_rounded,
          );
        }
        final skills = (snapshot.data ?? const <PlayerProgress>[])
            .map(
              (item) => (
                item.skillLabel,
                item.progress / 100,
                AppColors.primary,
              ),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Text('تقدمك', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 7),
            Text(
              'تابع تطور مهاراتك خطوة بخطوة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (skills.isEmpty
                              ? 0.0
                              : skills.map((e) => e.$2).reduce((a, b) => a + b) / skills.length)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                          strokeWidth: 8,
                          backgroundColor: AppColors.border,
                          color: AppColors.primary,
                        ),
                        Text(
                          '${skills.isEmpty ? 0 : (skills.map((e) => e.$2).reduce((a, b) => a + b) / skills.length * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مستوى التقدم العام',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'أداء ثابت هذا الأسبوع. استمر على نفس الوتيرة.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text('المهارات', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ...skills.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 17),
                child: _ProgressLine(
                  label: item.$1,
                  value: item.$2,
                  color: item.$3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlayerChallengesScreen extends StatelessWidget {
  const PlayerChallengesScreen({super.key, required this.repository});

  final TrainingRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Challenge>>(
      future: repository.fetchPlayerChallenges(repository.currentUserId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            title: 'تعذر تحميل التحديات',
            description: 'تحقق من الاتصال ثم حاول مرة أخرى.',
            icon: Icons.cloud_off_rounded,
          );
        }
        final challenges = snapshot.data ?? const <Challenge>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Text('التحديات', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 7),
            Text(
              'أهداف قصيرة تحافظ على إيقاعك التدريبي.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            ...challenges.asMap().entries.expand((entry) {
              final challenge = entry.value;
              final colors = [
                AppColors.warning,
                AppColors.primary,
                AppColors.info,
              ];
              final icons = [
                Icons.local_fire_department_rounded,
                Icons.emoji_events_outlined,
                Icons.sports_soccer_rounded,
              ];
              final progress = (challenge.progress / challenge.target).clamp(
                0.0,
                1.0,
              );
              return [
                _Challenge(
                  title: challenge.title,
                  subtitle: challenge.description,
                  progress: progress,
                  reward: '+${challenge.xpReward} XP',
                  icon: icons[entry.key % icons.length],
                  color: colors[entry.key % colors.length],
                ),
                if (entry.key != challenges.length - 1)
                  const SizedBox(height: 12),
              ];
            }),
          ],
        );
      },
    );
  }
}

class _Challenge extends StatelessWidget {
  const _Challenge({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.reward,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String reward;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              TagPill(label: reward, color: color),
            ],
          ),
          const SizedBox(height: 15),
          ProgressBar(value: progress, color: color),
          const SizedBox(height: 7),
          Text(
            '${(progress * 100).round()}% مكتمل',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
