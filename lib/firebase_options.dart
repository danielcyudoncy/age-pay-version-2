import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCH7SfFkZ1Ci-b0Bpl_glLRtoN7HWV1xwc',
    appId: '1:241674796862:web:f66306083255e4fb90f66f',
    messagingSenderId: '241674796862',
    projectId: 'agepay-9a80d',
    authDomain: 'agepay-9a80d.firebaseapp.com',
    storageBucket: 'agepay-9a80d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCH7SfFkZ1Ci-b0Bpl_glLRtoN7HWV1xwc',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: '241674796862',
    projectId: 'agepay-9a80d',
    storageBucket: 'agepay-9a80d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCH7SfFkZ1Ci-b0Bpl_glLRtoN7HWV1xwc',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '241674796862',
    projectId: 'agepay-9a80d',
    storageBucket: 'agepay-9a80d.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.agegrade.cls',
  );
}
