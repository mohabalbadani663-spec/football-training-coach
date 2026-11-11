import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.childBuilder, this.authService});

  final Widget Function(UserProfileData profile, VoidCallback onLogout) childBuilder;
  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService auth;
  UserProfileData? profile;
  bool authenticated = false;
  bool checkingSession = true;

  @override
  void initState() {
    super.initState();
    auth = widget.authService ?? LocalAuthService();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final existing = await auth.currentProfile();
    if (!mounted) return;
    setState(() {
      profile = existing;
      authenticated = existing != null;
      checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!authenticated) {
      return AuthScreen(
        auth: auth,
        onAuthenticated: (selectedProfile) => setState(() {
          profile = selectedProfile;
          authenticated = true;
        }),
      );
    }
    return widget.childBuilder(profile!, () {
      auth.signOut();
      if (mounted) {
        setState(() {
          profile = null;
          authenticated = false;
        });
      }
    });
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    required this.onAuthenticated,
  });

  final AuthService auth;
  final ValueChanged<UserProfileData> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isReset = false;
  bool loading = false;
  bool canResendConfirmation = false;
  bool loginCodeSent = false;
  UserRole role = UserRole.coach;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final loginCodeController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    loginCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
          children: [
            _BrandMark(),
            const SizedBox(height: 42),
            Text(
              isReset
                  ? 'استعادة الوصول'
                  : isLogin
                  ? 'مرحبًا بك من جديد'
                  : 'ابدأ رحلتك الرياضية',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 9),
            Text(
              isReset
                  ? 'أدخل بريدك وسنرسل لك رابطًا لاستعادة كلمة المرور.'
                  : isLogin
                  ? 'نظّم حصصك وواصل تطور فريقك من مكان واحد.'
                  : 'أنشئ حسابك كمدرب أو لاعب وابدأ التدريب بذكاء.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 30),
            if (!isLogin && !isReset) ...[
              TextField(
                controller: nameController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            if (!isReset && !isLogin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
            if (isLogin && loginCodeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: loginCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق المكوّن من 6 أرقام',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                  counterText: '',
                ),
              ),
            ],
            if (!isLogin && !isReset) ...[
              const SizedBox(height: 22),
              Text('أنا', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RoleChip(
                      label: 'مدرب',
                      icon: Icons.sports_rounded,
                      selected: role == UserRole.coach,
                      onTap: () => setState(() => role = UserRole.coach),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleChip(
                      label: 'لاعب',
                      icon: Icons.person_rounded,
                      selected: role == UserRole.player,
                      onTap: () => setState(() => role = UserRole.player),
                    ),
                  ),
                ],
              ),
            ],
            if (isLogin)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() => isReset = true),
                  child: const Text(
                    'نسيت كلمة المرور؟',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: loading
                  ? 'جارٍ المعالجة...'
                  : isReset
                  ? 'إرسال رابط الاستعادة'
                  : isLogin
                  ? loginCodeSent
                      ? 'تحقق من الرمز ودخول'
                      : 'إرسال رمز الدخول'
                  : 'إنشاء الحساب',
              icon: isReset
                  ? Icons.mail_outline_rounded
                  : isLogin
                  ? Icons.login_rounded
                  : Icons.arrow_back_rounded,
              onPressed: loading ? null : _submit,
            ),
            if (canResendConfirmation && !isReset) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: loading ? null : _resendConfirmation,
                child: const Text(
                  'إعادة إرسال رسالة التحقق',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!isReset)
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'أو',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            if (!isReset) ...[
              const SizedBox(height: 14),
              SecondaryButton(
                label: 'المتابعة باستخدام Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: () {},
                expand: true,
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  key: const ValueKey('signup-switch'),
                  onPressed: () => setState(() {
                    isLogin = !isLogin;
                    isReset = false;
                    loginCodeSent = false;
                    loginCodeController.clear();
                  }),
                  child: Text(
                    isLogin
                        ? 'ليس لديك حساب؟ إنشاء حساب'
                        : 'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ] else
              Center(
                child: TextButton(
                  onPressed: () => setState(() => isReset = false),
                  child: const Text(
                    'العودة إلى تسجيل الدخول',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (isLogin && !loginCodeSent) {
      await _requestLoginCode();
      return;
    }
    setState(() => loading = true);
    final result = isReset
        ? await widget.auth.resetPassword(emailController.text.trim())
        : isLogin
        ? await widget.auth.verifyLoginCode(
            email: emailController.text.trim(),
            token: loginCodeController.text,
          )
        : await widget.auth.signUp(
            email: emailController.text.trim(),
            password: passwordController.text,
            name: nameController.text.trim(),
            role: role,
          );
    if (!mounted) return;
    setState(() => loading = false);
    if (!result.success) {
      setState(() {
        canResendConfirmation = result.requiresEmailConfirmation;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'تعذر إكمال العملية')),
      );
      return;
    }
    if (isReset) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'تم إرسال الرابط')),
      );
      setState(() => isReset = false);
      return;
    }
    setState(() => canResendConfirmation = false);
    final profile = result.profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت العملية لكن لم تصل بيانات الحساب. حاول تسجيل الدخول مرة أخرى.')),
      );
      return;
    }
    widget.onAuthenticated(profile);
  }

  Future<void> _requestLoginCode() async {
    final email = emailController.text.trim();
    setState(() => loading = true);
    final result = await widget.auth.requestLoginCode(email: email);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (result.success) loginCodeSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'تعذر إرسال الرمز')),
    );
  }

  Future<void> _resendConfirmation() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => loading = true);
    try {
      await widget.auth.resendConfirmation(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة إرسال رسالة التحقق.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة. تحقق من البريد وحاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.sports_soccer_rounded,
            color: AppColors.background,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                'CoachIQ',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
            ),
              Text(
                'SMART FOOTBALL COACHING',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.primary : AppColors.muted,
            size: 19,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
