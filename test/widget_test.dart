import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:football_training_platform/screens/auth_screen.dart';
import 'package:football_training_platform/services/auth_service.dart';

void main() {
  testWidgets('auth screen renders Arabic login flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(auth: LocalAuthService(), onAuthenticated: (_) {}),
      ),
    );

    expect(find.text('مرحبًا بك من جديد'), findsOneWidget);
    expect(find.text('إرسال رمز الدخول'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('auth screen reveals six-digit code field after requesting OTP', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(auth: LocalAuthService(), onAuthenticated: (_) {}),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'player@example.com');
    await tester.tap(find.text('إرسال رمز الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('رمز التحقق المكوّن من 6 أرقام'), findsOneWidget);
    expect(find.text('تحقق من الرمز ودخول'), findsOneWidget);
  });

  testWidgets('auth screen switches to signup and exposes role choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(auth: LocalAuthService(), onAuthenticated: (_) {}),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('signup-switch')));
    await tester.pumpAndSettle();

    expect(find.text('ابدأ رحلتك الرياضية'), findsOneWidget);
    expect(find.text('مدرب'), findsOneWidget);
    expect(find.text('لاعب'), findsOneWidget);
  });
}
