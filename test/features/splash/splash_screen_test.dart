import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/splash/views/splash_screen.dart';
import 'package:cls/features/auth/views/login_screen.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('renders branded logo and tagline on brand green background',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify Scaffold has AppTheme.brandGreen background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.brandGreen);

      // Verify Tagline text
      expect(find.text('Financial Management System'), findsOneWidget);

      // Verify Progress Indicator exists
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance timer by 1200ms to verify navigation
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      // Should have navigated to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}

