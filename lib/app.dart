import 'package:flutter/material.dart';

import 'models/app_models.dart';
import 'screens/coach_home_screen.dart';
import 'screens/create_session_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/player_screens.dart';
import 'screens/profile_screen.dart';
import 'screens/team_screen.dart';
import 'screens/training_mode_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'widgets/app_widgets.dart';

class FootballTrainingApp extends StatelessWidget {
  const FootballTrainingApp({
    super.key,
    required this.profile,
    this.onLogout,
    required this.repository,
  });

  final UserProfileData profile;
  final VoidCallback? onLogout;
  final TrainingRepository repository;

  @override
  Widget build(BuildContext context) {
    return MainShell(
      profile: profile,
      onLogout: onLogout,
      repository: repository,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.profile,
    this.onLogout,
    required this.repository,
  });

  final UserProfileData profile;
  final VoidCallback? onLogout;
  final TrainingRepository repository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late UserRole role;
  late String userName;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    role = widget.profile.role;
    userName = widget.profile.name.isEmpty ? 'مستخدم' : widget.profile.name;
  }

  bool get isCoach => role == UserRole.coach;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      subtitle: isCoach ? 'مساحة المدرب' : 'مساحة اللاعب',
      currentIndex: currentIndex,
      isPlayer: !isCoach,
      onDestinationSelected: (index) => setState(() => currentIndex = index),
      child: _buildCurrentScreen(),
    );
  }

  String get _title {
    if (currentIndex == 0) return 'الرئيسية';
    if (isCoach) {
      return [
        'الرئيسية',
        'مكتبة التمارين',
        'الخطط الأسبوعية',
        'فريقي',
        'حسابي',
      ][currentIndex];
    }
    return ['الرئيسية', 'تدرّب', 'تقدمك', 'التحديات', 'حسابي'][currentIndex];
  }

  Widget _buildCurrentScreen() {
    if (isCoach) {
      switch (currentIndex) {
        case 0:
          return CoachHomeScreen(
            repository: widget.repository,
            userName: userName,
            onCreateSession: _openCreateSession,
            onExercises: () => setState(() => currentIndex = 1),
            onPlans: () => setState(() => currentIndex = 2),
            onTeam: () => setState(() => currentIndex = 3),
            onStartSession: _openTrainingMode,
          );
        case 1:
          return ExerciseLibraryScreen(repository: widget.repository);
        case 2:
          return PlansScreen(
            onCreateSession: _openCreateSession,
            repository: widget.repository,
          );
        case 3:
          return TeamScreen(repository: widget.repository);
        default:
          return ProfileScreen(
            role: role,
            userName: userName,
            onLogout: widget.onLogout,
            onJoinTeam: isCoach ? null : () => _joinTeam(context),
          );
      }
    }
    switch (currentIndex) {
      case 0:
        return PlayerHomeScreen(
          repository: widget.repository,
          userName: userName,
          onTrain: () => setState(() => currentIndex = 1),
          onProgress: () => setState(() => currentIndex = 2),
          onChallenges: () => setState(() => currentIndex = 3),
        );
      case 1:
        return PlayerTrainingScreen(repository: widget.repository);
      case 2:
        return PlayerProgressScreen(repository: widget.repository);
      case 3:
        return PlayerChallengesScreen(repository: widget.repository);
      default:
        return ProfileScreen(
          role: role,
          onLogout: widget.onLogout,
          userName: userName,
          onJoinTeam: () => _joinTeam(context),
        );
    }
  }

  Future<void> _joinTeam(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الانضمام إلى فريق'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'رمز الفريق', hintText: 'مثال: A1B2C3D4'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                final teamId = await widget.repository.joinTeamByCode(controller.text);
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teamId == null ? 'تعذر الانضمام إلى الفريق.' : 'تم الانضمام إلى الفريق بنجاح.')));
              } catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('رمز الفريق غير صحيح أو انتهت صلاحيته.')));
              }
            },
            child: const Text('انضمام'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _openCreateSession() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateSessionScreen(
          repository: widget.repository,
          onSave: (session) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إنشاء الحصة وحفظها بنجاح')),
            );
          },
        ),
      ),
    );
  }

  void _openTrainingMode(TrainingSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrainingModeScreen(session: session, repository: widget.repository)),
    );
  }
}
