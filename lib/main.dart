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
import 'features/calling/widgets/incoming_call_listener.dart';
import 'features/dashboard/views/home_router.dart';

/// Top-level background message handler required by Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  
  // On Android, debug builds automatically pass --start-paused to background
  // isolates spawned by FlutterFirebaseMessagingBackgroundService, which causes
  // an ANR (Signal 3) if opened standalone without a debugger attached.
  // We only register the background isolate handler in release/profile mode.
  if (!kDebugMode) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  await EnvService.init();

  await _initFirebase();

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service init note: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AgePay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const HomeRouter(),
      ),
      builder: (context, child) => IncomingCallListener(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
