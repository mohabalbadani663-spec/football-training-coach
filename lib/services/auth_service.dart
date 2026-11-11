import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';

class UserProfileData {
  const UserProfileData({
    required this.id,
    required this.name,
    required this.role,
    this.email,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? email;
}

class AuthResult {
  const AuthResult({
    required this.success,
    this.message,
    this.profile,
    this.requiresEmailConfirmation = false,
  });

  final bool success;
  final String? message;
  final UserProfileData? profile;
  final bool requiresEmailConfirmation;
}

class OtpRequestResult {
  const OtpRequestResult({required this.success, this.message});

  final bool success;
  final String? message;
}

abstract class AuthService {
  Future<AuthResult> signIn({required String email, required String password});
  Future<OtpRequestResult> requestLoginCode({required String email});
  Future<AuthResult> verifyLoginCode({required String email, required String token});
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  });
  Future<AuthResult> resetPassword(String email);
  Future<UserProfileData?> currentProfile();
  Future<void> resendConfirmation(String email);
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);

  final SupabaseClient client;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        return const AuthResult(
          success: false,
          message: 'تعذر إنشاء جلسة دخول. تحقق من البريد وكلمة المرور.',
        );
      }
      return AuthResult(success: true, profile: await _loadProfile(user));
    } on AuthException catch (error) {
      final lower = error.message.toLowerCase();
      final needsConfirmation =
          lower.contains('confirm') || lower.contains('email not');
      return AuthResult(
        success: false,
        message: needsConfirmation
            ? 'يجب تأكيد البريد الإلكتروني أولًا. تحقق من بريدك ثم حاول تسجيل الدخول.'
            : error.message,
        requiresEmailConfirmation: needsConfirmation,
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'تعذر الاتصال بالخادم. تحقق من الإنترنت وإعدادات Supabase.',
      );
    }
  }

  @override
  Future<OtpRequestResult> requestLoginCode({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return const OtpRequestResult(success: false, message: 'أدخل بريدًا إلكترونيًا صحيحًا.');
    }
    try {
      await client.auth.signInWithOtp(email: normalized, shouldCreateUser: false);
      return const OtpRequestResult(success: true, message: 'تم إرسال رمز من 6 أرقام إلى بريدك الإلكتروني.');
    } on AuthException catch (error) {
      return OtpRequestResult(success: false, message: error.message);
    } catch (_) {
      return const OtpRequestResult(success: false, message: 'تعذر إرسال الرمز. تحقق من البريد والاتصال وحاول مرة أخرى.');
    }
  }

  @override
  Future<AuthResult> verifyLoginCode({required String email, required String token}) async {
    final normalized = email.trim().toLowerCase();
    final code = token.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return const AuthResult(success: false, message: 'أدخل رمز التحقق المكوّن من 6 أرقام.');
    }
    try {
      final response = await client.auth.verifyOTP(email: normalized, token: code, type: OtpType.email);
      final user = response.user;
      if (user == null || response.session == null) {
        return const AuthResult(success: false, message: 'الرمز غير صحيح أو انتهت صلاحيته.');
      }
      return AuthResult(success: true, profile: await _loadProfile(user));
    } on AuthException catch (error) {
      return AuthResult(success: false, message: 'الرمز غير صحيح أو انتهت صلاحيته: ${error.message}');
    } catch (_) {
      return const AuthResult(success: false, message: 'تعذر التحقق من الرمز. حاول مرة أخرى.');
    }
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': role.name},
      );
      final user = response.user;
      if (user == null) {
        return const AuthResult(
          success: false,
          message: 'تعذر إنشاء الحساب. حاول مرة أخرى.',
        );
      }
      if (response.session == null) {
        try {
          await resendConfirmation(email);
        } catch (_) {
          // The account still exists; the user can request another email later.
        }
        return const AuthResult(
          success: false,
          requiresEmailConfirmation: true,
          message: 'تم إنشاء الحساب وإرسال رسالة التحقق. افتح بريدك ثم سجّل الدخول.',
        );
      }
      return AuthResult(
        success: true,
        profile: await _loadProfile(user, fallbackName: name, fallbackRole: role),
      );
    } on AuthException catch (error) {
      return AuthResult(success: false, message: error.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'تعذر الاتصال بالخادم. تحقق من الإنترنت وإعدادات Supabase.',
      );
    }
  }

  Future<UserProfileData> _loadProfile(
    User user, {
    String? fallbackName,
    UserRole? fallbackRole,
  }) async {
    try {
      final row = await client
          .from('profiles')
          .select('id, full_name, role')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        final dbName = (row['full_name'] as String? ?? '').trim();
        final metadataName = (user.userMetadata?['name'] as String? ?? '').trim();
        final displayName = dbName.isNotEmpty
            ? dbName
            : metadataName.isNotEmpty
                ? metadataName
                : _nameFromEmail(user.email);
        return UserProfileData(
          id: user.id,
          name: displayName,
          role: _roleFromValue(row['role'] as String?) ??
              fallbackRole ?? UserRole.player,
          email: user.email,
        );
      }
    } catch (_) {
      // The auth session remains valid if the profile row is delayed.
    }
    return UserProfileData(
      id: user.id,
      name: _displayName(user, fallbackName: fallbackName),
      role: fallbackRole ??
          _roleFromValue(user.userMetadata?['role'] as String?) ??
          UserRole.player,
      email: user.email,
    );
  }

  String _displayName(User user, {String? fallbackName}) {
    final supplied = (fallbackName ?? '').trim();
    if (supplied.isNotEmpty) return supplied;
    final metadataName = (user.userMetadata?['name'] as String? ?? '').trim();
    if (metadataName.isNotEmpty) return metadataName;
    return _nameFromEmail(user.email);
  }

  String _nameFromEmail(String? email) {
    final localPart = email?.split('@').first.trim() ?? '';
    return localPart.isNotEmpty ? localPart : 'مستخدم';
  }

  UserRole? _roleFromValue(String? value) {
    if (value == UserRole.coach.name) return UserRole.coach;
    if (value == UserRole.player.name) return UserRole.player;
    return null;
  }

  @override
  Future<UserProfileData?> currentProfile() async {
    final user = client.auth.currentUser;
    final session = client.auth.currentSession;
    if (user == null || session == null) return null;
    return _loadProfile(user);
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await client.auth.resend(type: OtpType.signup, email: email);
  }

  @override
  Future<AuthResult> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
      return const AuthResult(
        success: true,
        message: 'تم إرسال رابط استعادة كلمة المرور إلى بريدك.',
      );
    } on AuthException catch (error) {
      return AuthResult(success: false, message: error.message);
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

class LocalAuthService implements AuthService {
  bool signedIn = false;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!email.contains('@') || password.length < 6) {
      return const AuthResult(
        success: false,
        message: 'تأكد من البريد وكلمة المرور (6 أحرف على الأقل).',
      );
    }
    signedIn = true;
    return AuthResult(
      success: true,
      profile: UserProfileData(
        id: 'local-user',
        name: 'مستخدم تجريبي',
        role: UserRole.coach,
        email: email,
      ),
    );
  }

  @override
  Future<OtpRequestResult> requestLoginCode({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!email.contains('@')) {
      return const OtpRequestResult(success: false, message: 'أدخل بريدًا إلكترونيًا صحيحًا.');
    }
    return const OtpRequestResult(success: true, message: 'تم إرسال رمز تجريبي: 123456');
  }

  @override
  Future<AuthResult> verifyLoginCode({required String email, required String token}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (token.trim() != '123456') {
      return const AuthResult(success: false, message: 'الرمز التجريبي غير صحيح. استخدم 123456.');
    }
    signedIn = true;
    return AuthResult(
      success: true,
      profile: UserProfileData(id: 'local-user', name: 'مستخدم تجريبي', role: UserRole.coach, email: email),
    );
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (name.trim().isEmpty || !email.contains('@') || password.length < 6) {
      return const AuthResult(
        success: false,
        message: 'أكمل الاسم والبريد وكلمة مرور من 6 أحرف على الأقل.',
      );
    }
    signedIn = true;
    return AuthResult(
      success: true,
      profile: UserProfileData(
        id: 'local-user',
        name: name.trim(),
        role: role,
        email: email,
      ),
    );
  }

  @override
  Future<UserProfileData?> currentProfile() async => null;

  @override
  Future<void> resendConfirmation(String email) async {}

  @override
  Future<AuthResult> resetPassword(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!email.contains('@')) {
      return const AuthResult(
        success: false,
        message: 'أدخل بريدًا إلكترونيًا صحيحًا.',
      );
    }
    return const AuthResult(
      success: true,
      message: 'تم إرسال رابط استعادة كلمة المرور إلى بريدك.',
    );
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}
