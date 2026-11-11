import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'models/app_models.dart';
import 'models/tenant_models.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await _buildAuthService();
  final repository = _buildTrainingRepository();

  // Start the UI first. A queued offline sync must never be able to keep
  // Android on the native splash screen if it encounters bad/stale data.
  runApp(_Bootstrap(authService: authService, repository: repository));

  // Retry queued writes in the background after the first frame. Any failure
  // is intentionally isolated from application startup.
  try {
    await repository.syncPending();
  } catch (_) {
    // The queue will be retried on a later authenticated launch.
  }
}

TrainingRepository _buildTrainingRepository() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && publishableKey.isNotEmpty) {
    return SupabaseTrainingRepository(Supabase.instance.client);
  }
  if (const bool.fromEnvironment('ALLOW_LOCAL_DEMO', defaultValue: false)) {
    return LocalTrainingRepository();
  }
  return _UnavailableTrainingRepository();
}

Future<AuthService> _buildAuthService() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && publishableKey.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    return SupabaseAuthService(Supabase.instance.client);
  }
  if (const bool.fromEnvironment('ALLOW_LOCAL_DEMO', defaultValue: false)) {
    return LocalAuthService();
  }
  return _UnavailableAuthService();
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap({required this.authService, required this.repository});

  final AuthService authService;
  final TrainingRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoachIQ',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AuthGate(
          authService: authService,
          childBuilder: (profile, onLogout) => FootballTrainingApp(
            profile: profile,
            onLogout: onLogout,
            repository: repository,
          ),
        ),
      ),
    );
  }
}


class _UnavailableAuthService implements AuthService {
  AuthResult _error() => const AuthResult(
        success: false,
        message: 'إعدادات Supabase غير مكتملة. شغّل التطبيق باستخدام SUPABASE_URL وSUPABASE_PUBLISHABLE_KEY.',
      );

  @override Future<AuthResult> signIn({required String email, required String password}) async => _error();
  @override Future<OtpRequestResult> requestLoginCode({required String email}) async => OtpRequestResult(success: false, message: _error().message);
  @override Future<AuthResult> verifyLoginCode({required String email, required String token}) async => _error();
  @override Future<AuthResult> signUp({required String email, required String password, required String name, required UserRole role}) async => _error();
  @override Future<AuthResult> resetPassword(String email) async => _error();
  @override Future<UserProfileData?> currentProfile() async => null;
  @override Future<void> resendConfirmation(String email) async => throw StateError(_error().message!);
  @override Future<void> signOut() async {}
}

class _UnavailableTrainingRepository implements TrainingRepository {
  Never _error() => throw StateError('إعدادات Supabase غير مكتملة.');
  @override String? get currentUserId => null;
  @override Future<Organization?> fetchMyOrganization() => Future.error(_error());
  @override Future<List<TeamInfo>> fetchCoachTeams() => Future.error(_error());
  @override Future<String?> resolveCurrentTeamId() => Future.error(_error());
  @override Future<List<Exercise>> fetchExercises() => Future.error(_error());
  @override Future<List<TrainingSession>> fetchCoachSessions(String coachId) => Future.error(_error());
  @override Future<List<TrainingSession>> fetchPlayerSessions(String playerId) => Future.error(_error());
  @override Future<List<Player>> fetchTeamPlayers(String teamId) => Future.error(_error());
  @override Future<String?> joinTeamByCode(String code) => Future.error(_error());
  @override Future<void> invitePlayer({required String teamId, required String email}) => Future.error(_error());
  @override Future<void> saveSession({required String coachId, required TrainingSession session, String? teamId}) => Future.error(_error());
  @override Future<void> syncPending() async {}
  @override Future<List<PlayerProgress>> fetchPlayerProgress(String playerId) => Future.error(_error());
  @override Future<void> savePlayerProgress({required String playerId, required PlayerProgress progress}) => Future.error(_error());
  @override Future<List<Challenge>> fetchPlayerChallenges(String playerId) => Future.error(_error());
  @override Future<void> saveChallengeProgress({required String playerId, required String challengeId, required int progress, required bool completed}) => Future.error(_error());
}
