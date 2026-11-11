import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.isPlayer = false,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isPlayer;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'الرئيسية',
      ),
      const NavigationDestination(
        icon: Icon(Icons.sports_soccer_outlined),
        selectedIcon: Icon(Icons.sports_soccer),
        label: 'تدريب',
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_note_outlined),
        selectedIcon: const Icon(Icons.event_note),
        label: isPlayer ? 'التقدم' : 'الخطط',
      ),
      NavigationDestination(
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups),
        label: isPlayer ? 'التحديات' : 'الفريق',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'حسابي',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(top: false, child: child),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_back_rounded, size: 19),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.add_rounded, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.foreground,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.height = 7,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: AppColors.border,
        color: color,
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.compact = false,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExerciseVisual(exercise: exercise, size: compact ? 62 : 76),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.muted,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  exercise.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TagPill(
                      label: '${exercise.duration} د',
                      icon: Icons.timer_outlined,
                      color: AppColors.info,
                    ),
                    TagPill(
                      label: exercise.difficulty,
                      icon: Icons.trending_up_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

class ExerciseVisual extends StatelessWidget {
  const ExerciseVisual({super.key, required this.exercise, this.size = 76});

  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(exercise.color),
            Color(exercise.color).withValues(alpha: 0.42),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: -14,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: Icon(
              _iconFor(exercise.category),
              color: Colors.white.withValues(alpha: 0.92),
              size: size * 0.42,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.technical:
        return Icons.sports_soccer;
      case ExerciseCategory.physical:
        return Icons.speed_rounded;
      case ExerciseCategory.tactical:
        return Icons.account_tree_outlined;
      case ExerciseCategory.cognitive:
        return Icons.psychology_outlined;
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
