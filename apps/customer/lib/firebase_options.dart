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
      return web;
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNl63a9xCTPa9RTcnZr7XuhxxaWHf-rgk',
    appId: '1:427394139285:android:62d1433d26748060ec079c',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    storageBucket: 'akjol-f479a.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBsFIrA-0J6BuY7iVoFRYCDJQr4xUJpoYA',
    appId: '1:427394139285:web:f3e3224841273854ec079c',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    authDomain: 'akjol-f479a.firebaseapp.com',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    measurementId: 'G-Q79FTKYTYE',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA8VRtlitN06WcDlGzFg_RvqtickZiPkIE',
    appId: '1:427394139285:ios:64d9196ddaf2d396ec079c',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    iosBundleId: 'com.akjolui.customer',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA8VRtlitN06WcDlGzFg_RvqtickZiPkIE',
    appId: '1:427394139285:ios:2dc6366f9c6d4cb7ec079c',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    iosBundleId: 'com.akjolui.customer',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBsFIrA-0J6BuY7iVoFRYCDJQr4xUJpoYA',
    appId: '1:427394139285:web:999072ac9fc6d506ec079c',
    messagingSenderId: '427394139285',
    projectId: 'akjol-f479a',
    authDomain: 'akjol-f479a.firebaseapp.com',
    storageBucket: 'akjol-f479a.firebasestorage.app',
    measurementId: 'G-PRL6MN3PN6',
  );

}