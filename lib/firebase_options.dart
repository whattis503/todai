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
    apiKey: 'AIzaSyD0R2B7CTXjyyTHhcuOSTrKt5FWq3mjuVs',
    appId: '1:43937279527:web:23dd31e0d59b684b242802',
    messagingSenderId: '43937279527',
    projectId: 'toda-56a3d',
    authDomain: 'toda-56a3d.firebaseapp.com',
    storageBucket: 'toda-56a3d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0R2B7CTXjyyTHhcuOSTrKt5FWq3mjuVs',
    appId: '1:43937279527:android:23dd31e0d59b684b242802',
    messagingSenderId: '43937279527',
    projectId: 'toda-56a3d',
    storageBucket: 'toda-56a3d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD0R2B7CTXjyyTHhcuOSTrKt5FWq3mjuVs',
    appId: '1:43937279527:ios:23dd31e0d59b684b242802',
    messagingSenderId: '43937279527',
    projectId: 'toda-56a3d',
    storageBucket: 'toda-56a3d.firebasestorage.app',
    iosBundleId: 'com.todai.todai',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD0R2B7CTXjyyTHhcuOSTrKt5FWq3mjuVs',
    appId: '1:43937279527:macos:23dd31e0d59b684b242802',
    messagingSenderId: '43937279527',
    projectId: 'toda-56a3d',
    storageBucket: 'toda-56a3d.firebasestorage.app',
    iosBundleId: 'com.todai.todai',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD0R2B7CTXjyyTHhcuOSTrKt5FWq3mjuVs',
    appId: '1:43937279527:windows:23dd31e0d59b684b242802',
    messagingSenderId: '43937279527',
    projectId: 'toda-56a3d',
    storageBucket: 'toda-56a3d.firebasestorage.app',
  );
}
