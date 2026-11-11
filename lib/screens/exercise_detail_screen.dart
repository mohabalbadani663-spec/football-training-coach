import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/pitch_diagram.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('تفاصيل التمرين'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        children: [
          _HeroExercise(exercise: exercise),
          const SizedBox(height: 14),
          PitchDiagram(exercise: exercise),
          const SizedBox(height: 22),
          Text(
            exercise.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            exercise.description,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagPill(label: exercise.age, icon: Icons.calendar_month_outlined),
              TagPill(
                label: exercise.players,
                icon: Icons.groups_outlined,
                color: AppColors.info,
              ),
              TagPill(
                label: '${exercise.duration} دقيقة',
                icon: Icons.timer_outlined,
                color: AppColors.warning,
              ),
              TagPill(
                label: exercise.difficulty,
                icon: Icons.trending_up_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (exercise.space.trim().isNotEmpty || exercise.equipment.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'المساحة: ${exercise.space.isEmpty ? 'غير محددة' : exercise.space}\nالمعدات: ${exercise.equipment.isEmpty ? 'غير محددة' : exercise.equipment}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (exercise.space.trim().isNotEmpty || exercise.equipment.trim().isNotEmpty)
            const SizedBox(height: 22),
          Text('طريقة التنفيذ', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...exercise.instructions.asMap().entries.map(
            (entry) => _Instruction(index: entry.key + 1, text: entry.value),
          ),
          const SizedBox(height: 22),
          Text('نقاط التدريب', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...exercise.coachingPoints.map((point) => _Bullet(text: point)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _Variation(
                  title: 'تبسيط',
                  text: exercise.regression,
                  color: AppColors.info,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Variation(
                  title: 'تطوير',
                  text: exercise.progression,
                  color: AppColors.primary,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroExercise extends StatelessWidget {
  const _HeroExercise({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(exercise.color), AppColors.surfaceAlt],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -32,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.11),
              ),
            ),
          ),
          Center(
            child: exercise.diagramUrl?.trim().isNotEmpty == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      exercise.diagramUrl!,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => const Icon(
                        Icons.sports_soccer_rounded,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.sports_soccer_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: TagPill(
              label: exercise.category.label,
              color: Colors.white,
              icon: Icons.category_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _Variation extends StatelessWidget {
  const _Variation({
    required this.title,
    required this.text,
    required this.color,
    required this.icon,
  });
  final String title;
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 9),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}
