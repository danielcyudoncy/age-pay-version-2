// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/views/splash_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'features/notifications/services/notification_service.dart';
import 'core/services/env_service.dart';
import 'features/settings/controllers/settings_provider.dart';
import 'package:flutter/foundation.dart';

/// Top-level background message handler required by Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (kReleaseMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvService.init();

  await _initFirebase();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'AgePay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
