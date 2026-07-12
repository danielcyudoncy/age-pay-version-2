import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvService {
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
  }

  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseWebAppId => dotenv.env['FIREBASE_WEB_APP_ID'] ?? '';
  static String get firebaseAndroidAppId => dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '';
  static String get firebaseIosAppId => dotenv.env['FIREBASE_IOS_APP_ID'] ?? '';
  static String get firebaseIosClientId => dotenv.env['FIREBASE_IOS_CLIENT_ID'] ?? '';
}
