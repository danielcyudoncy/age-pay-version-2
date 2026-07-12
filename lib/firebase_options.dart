import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'core/services/env_service.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: EnvService.firebaseApiKey,
    appId: EnvService.firebaseWebAppId,
    messagingSenderId: '241674796862',
    projectId: 'agepay-9a80d',
    authDomain: 'agepay-9a80d.firebaseapp.com',
    storageBucket: 'agepay-9a80d.firebasestorage.app',
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: EnvService.firebaseApiKey,
    appId: EnvService.firebaseAndroidAppId,
    messagingSenderId: '241674796862',
    projectId: 'agepay-9a80d',
    storageBucket: 'agepay-9a80d.firebasestorage.app',
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: EnvService.firebaseApiKey,
    appId: EnvService.firebaseIosAppId,
    messagingSenderId: '241674796862',
    projectId: 'agepay-9a80d',
    storageBucket: 'agepay-9a80d.firebasestorage.app',
    iosClientId: EnvService.firebaseIosClientId,
    iosBundleId: 'com.agegrade.cls',
  );
}
