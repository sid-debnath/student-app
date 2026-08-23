import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA8xJQ3PTKNa5C1ji-6GFj1eu-XI99ue9U',
    appId: '1:609590215661:web:35351794d28512c7e4dde4',
    messagingSenderId: '609590215661',
    projectId: 'student-mgmt-sdd2011-bddf7',
    authDomain: 'student-mgmt-sdd2011-bddf7.firebaseapp.com',
    storageBucket: 'student-mgmt-sdd2011-bddf7.firebasestorage.app',
    measurementId: 'G-4XPZKFGJC5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBLqSayzwOXDnz75vFajSY-e8G5yYId0Mo',
    appId: '1:609590215661:android:b814a2bf740486c1e4dde4',
    messagingSenderId: '609590215661',
    projectId: 'student-mgmt-sdd2011-bddf7',
    storageBucket: 'student-mgmt-sdd2011-bddf7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9lElMjDCZLNRK0Ap9goOyfyOp2j98yrs',
    appId: '1:609590215661:ios:13786872a723dfa5e4dde4',
    messagingSenderId: '609590215661',
    projectId: 'student-mgmt-sdd2011-bddf7',
    storageBucket: 'student-mgmt-sdd2011-bddf7.firebasestorage.app',
    iosBundleId: 'com.institution.studentApp',
  );
}
