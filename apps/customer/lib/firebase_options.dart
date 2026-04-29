// File generated manually to match courier Firebase config.
// Project: akjol-f479a
//
// IMPORTANT: After adding com.akjolui.customer in Firebase Console,
// run `flutterfire configure` to regenerate this file with correct appId.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace appId after adding com.akjolui.customer in Firebase Console
  // and downloading google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNl63a9xCTPa9RTcnZr7XuhxxaWHf-rgk',
    appId: '1:427394139285:android:REPLACE_WITH_CUSTOMER_APP_ID',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    storageBucket: 'akjol-f479a.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBsFIrA-0J6BuY7iVoFRYCDJQr4xUJpoYA',
    appId: '1:427394139285:web:9867b07f94e2984aec079c',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    authDomain: 'akjol-f479a.firebaseapp.com',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    measurementId: 'G-CEFBF81WNR',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA8VRtlitN06WcDlGzFg_RvqtickZiPkIE',
    appId: '1:427394139285:ios:REPLACE_WITH_CUSTOMER_IOS_APP_ID',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    iosBundleId: 'com.akjolui.customer',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA8VRtlitN06WcDlGzFg_RvqtickZiPkIE',
    appId: '1:427394139285:ios:REPLACE_WITH_CUSTOMER_IOS_APP_ID',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    iosBundleId: 'com.akjolui.customer',
  );
}
