import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/app_config.dart';
import '../core/branding.dart';
import '../core/constants.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/institution.dart';
import 'paths.dart';

/// Spark: client Auth + Firestore. Production: try Functions, then the same client path.
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

  Future<void> bootstrapInstitution({
    required String institutionName,
    required String displayName,
  }) async {
    if (AppConfig.useCloudFunctions) {
      try {
        await FirebaseFunctions.instance.httpsCallable('bootstrapInstitution').call({
          'institutionName': institutionName,
          'displayName': displayName,
        });
        await _auth.currentUser?.getIdToken(true);
        return;
      } catch (_) {
        // Spark leftover, missing Functions, or permission — use client path.
      }
    }
    await _bootstrapInstitutionOnClient(
      institutionName: institutionName,
      displayName: displayName,
    );
  }

  Future<void> _bootstrapInstitutionOnClient({
    required String institutionName,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in or create an account first.');
    }
    await user.getIdToken(true);
    final institutionRef = _db.collection('institutions').doc(kDefaultInstitutionId);
    try {
      final existing = await institutionRef.get();
      if (existing.exists) {
        throw StateError('An institution is already set up. Sign in with an existing account.');
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    final batch = _db.batch();
    batch.set(institutionRef, {
      'name': institutionName,
      'createdAt': FieldValue.serverTimestamp(),
      'branding': BrandConfig.current.toFirestore(),
    });
    batch.set(institutionRef.collection('users').doc(user.uid), {
      'email': user.email ?? '',
      'displayName': displayName,
      'role': UserRole.admin.name,
      'institutionId': kDefaultInstitutionId,
      'classIds': <String>[],
      'studentIds': <String>[],
    });
    await batch.commit();
  }

  Future<void> createInstitutionUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    List<String> classIds = const [],
    List<String> studentIds = const [],
  }) async {
    if (AppConfig.useCloudFunctions) {
      try {
        await FirebaseFunctions.instance.httpsCallable('createInstitutionUser').call({
          'email': email,
          'password': password,
          'displayName': displayName,
          'role': role.name,
          'classIds': classIds,
          'studentIds': studentIds,
        });
        return;
      } catch (_) {}
    }
    await _createInstitutionUserOnClient(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      classIds: classIds,
      studentIds: studentIds,
    );
  }

  Future<void> _createInstitutionUserOnClient({
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
      await InstitutionPaths(kDefaultInstitutionId).users.doc(uid).set({
        'email': email,
        'displayName': displayName.isEmpty ? email : displayName,
        'role': role.name,
        'institutionId': kDefaultInstitutionId,
        'classIds': classIds,
        'studentIds': studentIds,
      });
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Stream<AppUser?> watchProfile(User user) {
    return InstitutionPaths(kDefaultInstitutionId).users.doc(user.uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<Institution?> watchInstitution() {
    return InstitutionPaths(kDefaultInstitutionId).institution.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Institution.fromMap(snap.id, snap.data()!);
    });
  }

  Future<void> saveFcmToken(AppUser profile) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null) return;
      await InstitutionPaths(profile.institutionId).users.doc(profile.id).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      await messaging.subscribeToTopic('institution_${profile.institutionId}_all');
      for (final classId in profile.classIds) {
        await messaging.subscribeToTopic(
          'institution_${profile.institutionId}_class_$classId',
        );
      }
    } catch (_) {
      // Web/Spark: permission or unsupported browser — do not fail the session.
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
