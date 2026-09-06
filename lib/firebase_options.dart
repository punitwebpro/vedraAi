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
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBgcxY5DFzuNM4y_ljfU2fmTcGC5SQE-do',
    appId: '1:847958872910:web:placeholder',
    messagingSenderId: '847958872910',
    projectId: 'vedra-70f58',
    storageBucket: 'vedra-70f58.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgcxY5DFzuNM4y_ljfU2fmTcGC5SQE-do',
    appId: '1:847958872910:android:placeholder',
    messagingSenderId: '847958872910',
    projectId: 'vedra-70f58',
    storageBucket: 'vedra-70f58.firebasestorage.app',
  );
}
