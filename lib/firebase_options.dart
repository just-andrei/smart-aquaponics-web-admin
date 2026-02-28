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
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBJ_KHOTY2iVmSuCSvXPV1hnmAKtoF9PrE',
    appId: '1:881996302272:web:de7dd620786a2f3b40ea25',
    messagingSenderId: '881996302272',
    projectId: 'smart-aquaponics-e8f5f',
    authDomain: 'smart-aquaponics-e8f5f.firebaseapp.com',
    storageBucket: 'smart-aquaponics-e8f5f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJ_KHOTY2iVmSuCSvXPV1hnmAKtoF9PrE',
    appId: '1:881996302272:android:de7dd620786a2f3b40ea25',
    messagingSenderId: '881996302272',
    projectId: 'smart-aquaponics-e8f5f',
    storageBucket: 'smart-aquaponics-e8f5f.firebasestorage.app',
  );
}
