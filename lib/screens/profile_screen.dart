import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.role,
    required this.userName,
    this.onLogout,
    this.onJoinTeam,
  });
  final UserRole role;
  final String userName;
  final VoidCallback? onLogout;
  final VoidCallback? onJoinTeam;

  @override
  Widget build(BuildContext context) {
    final isCoach = role == UserRole.coach;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCoach ? Icons.sports_rounded : Icons.person_rounded,
                  size: 31,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isCoach ? 'مدرب' : 'لاعب',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          'نوع الحساب',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 11),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(isCoach ? Icons.sports_rounded : Icons.person_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(isCoach ? 'مدرب' : 'لاعب', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 27),
        Text('الإعدادات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 11),
        _SettingTile(
          icon: Icons.language_rounded,
          title: 'اللغة',
          value: 'العربية',
          onTap: () {},
        ),
        _SettingTile(
          icon: Icons.notifications_none_rounded,
          title: 'الإشعارات',
          value: 'مفعّلة',
          onTap: () {},
        ),
        _SettingTile(
          icon: Icons.dark_mode_outlined,
          title: 'المظهر',
          value: 'داكن',
          onTap: () {},
        ),
        _SettingTile(
          icon: Icons.help_outline_rounded,
          title: 'المساعدة والدعم',
          onTap: () {},
        ),
        const SizedBox(height: 15),
        if (!isCoach && onJoinTeam != null) ...[
          PrimaryButton(
            label: 'الانضمام إلى فريق',
            icon: Icons.group_add_rounded,
            onPressed: onJoinTeam,
            expand: true,
          ),
          const SizedBox(height: 10),
        ],
        SecondaryButton(
          label: 'تسجيل الخروج',
          icon: Icons.logout_rounded,
          onPressed: onLogout,
          expand: true,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'CoachIQ  •  Smart Football Coaching',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 2),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.muted, size: 19),
    ),
    title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(value!, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
      ],
    ),
    onTap: onTap,
  );
}
