import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/constants.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';
import 'paths.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _secondaryAppName = 'userAdmin';

  Stream<User?> authState() => _auth.authStateChanges();

  Future<void> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> bootstrapSchool({
    required String schoolName,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in or create an account first.');
    }
    await user.getIdToken(true);
    final schoolRef = _db.collection('schools').doc(kDefaultSchoolId);
    try {
      final existing = await schoolRef.get();
      if (existing.exists) {
        throw StateError('A school is already set up. Sign in with an existing account.');
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    final classRef = schoolRef.collection('classes').doc();
    final studentRef = schoolRef.collection('students').doc();
    final batch = _db.batch();
    batch.set(schoolRef, {
      'name': schoolName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(schoolRef.collection('users').doc(user.uid), {
      'email': user.email ?? '',
      'displayName': displayName,
      'role': UserRole.admin.name,
      'schoolId': kDefaultSchoolId,
      'classIds': <String>[],
      'studentIds': <String>[],
    });
    batch.set(classRef, {
      'name': '10',
      'section': 'A',
      'year': DateTime.now().year,
      'teacherIds': <String>[],
    });
    batch.set(studentRef, {
      'name': 'Demo Student',
      'classId': classRef.id,
      'roll': '1',
      'viewerUids': <String>[],
    });
    await batch.commit();
  }

  Future<void> createSchoolUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    List<String> classIds = const [],
    List<String> studentIds = const [],
  }) async {
    if (_auth.currentUser == null) {
      throw StateError('Admin must be signed in.');
    }
    final app = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw StateError('Could not create the account.');
      }
      if (displayName.isNotEmpty) {
        await cred.user!.updateDisplayName(displayName);
      }
      await SchoolPaths(kDefaultSchoolId).users.doc(uid).set({
        'email': email,
        'displayName': displayName.isEmpty ? email : displayName,
        'role': role.name,
        'schoolId': kDefaultSchoolId,
        'classIds': classIds,
        'studentIds': studentIds,
      });
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Stream<AppUser?> watchProfile(User user) {
    return SchoolPaths(kDefaultSchoolId).users.doc(user.uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(snap.id, snap.data()!);
    });
  }

  Future<void> saveFcmToken(AppUser profile) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token == null) return;
    await SchoolPaths(profile.schoolId).users.doc(profile.id).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
    await messaging.subscribeToTopic('school_${profile.schoolId}_all');
    for (final classId in profile.classIds) {
      await messaging.subscribeToTopic('school_${profile.schoolId}_class_$classId');
    }
  }


  Future<FirebaseApp> _secondaryApp() async {
    final existing = Firebase.apps.where((app) => app.name == _secondaryAppName);
    if (existing.isNotEmpty) return existing.first;
    return Firebase.initializeApp(
      name: _secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
