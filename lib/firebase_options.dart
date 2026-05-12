import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Solo plataforma web soportada.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC23oHbUd9MV_tJ0jFZNQffSRkYwbD5Wnk',
    authDomain: 'inventariog-cf.firebaseapp.com',
    projectId: 'inventariog-cf',
    storageBucket: 'inventariog-cf.firebasestorage.app',
    messagingSenderId: '188201900358',
    appId: '1:188201900358:web:747f3da87abf605de1ad47',
  );
}
