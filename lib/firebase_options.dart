import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('This config only supports web');
  }

  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyAQPAqF1CY2JIEWrK-63hfBE_8IoUNcNOk",
      authDomain: "attendence-tracker-b0ff2.firebaseapp.com",
      projectId: "attendence-tracker-b0ff2",
      storageBucket: "attendence-tracker-b0ff2.firebasestorage.app",
      messagingSenderId: "341733726341",
      appId: "1:341733726341:web:29fca1597e42691bf2f1ec",
      measurementId: "G-MWT4Q92FMS"
  );
}