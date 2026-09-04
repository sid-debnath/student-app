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
  FirebaseAuth get auth => _auth;
  final FirebaseFirestore _db;

  static const _secondaryAppName = 'userAdmin';

  /// Temp password from the sign-in that triggered first-login change.
  /// Cleared on sign-out or after a successful password change.
  String? _pendingTemporaryPassword;

  String? get pendingTemporaryPassword => _pendingTemporaryPassword;

  void rememberTemporaryPasswordForChange(String password) {
    _pendingTemporaryPassword = password;
  }

  void clearTemporaryPasswordMemory() {
    _pendingTemporaryPassword = null;
  }

  /// First-login gate: temporary password must be known, and new must differ.
  ///
  /// Important: a null/empty [temporaryPassword] must fail. The previous helper
  /// skipped the check when memory was empty, which let `123456` → `123456`
  /// clear `mustChangePassword` after a no-op Auth update.
  static void validateFirstLoginNewPassword({
    required String newPassword,
    required String? temporaryPassword,
  }) {
    if (temporaryPassword == null || temporaryPassword.isEmpty) {
      throw StateError(
        'Enter the temporary password from your admin, then choose a '
        'different new password.',
      );
    }
    if (newPassword == temporaryPassword) {
      throw StateError(
        'New password cannot be the same as the temporary password. '
        'Choose a different one.',
      );
    }
  }

  Stream<User?> authState() => _auth.authStateChanges();

  Future<User> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw StateError('Sign in failed. Check the email and password.');
    }
    // Remember immediately so the change-password screen cannot race ahead
    // with a null temporary password and skip reuse validation.
    rememberTemporaryPasswordForChange(password);
    return user;
  }

  Future<void> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    clearTemporaryPasswordMemory();
    return _auth.signOut();
  }

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
      'mustChangePassword': false,
    });
    await batch.commit();
  }

  Future<String?> createInstitutionUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    List<String> classIds = const [],
    List<String> studentIds = const [],
    String fatherPhone = '',
    String motherPhone = '',
    String alternativePhone = '',
    ViewerAccountType? viewerAccountType,
    String? previousPassword,
  }) async {
    if (AppConfig.useCloudFunctions) {
      try {
        final result =
            await FirebaseFunctions.instance.httpsCallable('createInstitutionUser').call({
          'email': email,
          'password': password,
          'displayName': displayName,
          'role': role.name,
          'classIds': classIds,
          'studentIds': studentIds,
          'fatherPhone': fatherPhone,
          'motherPhone': motherPhone,
          'alternativePhone': alternativePhone,
          if (viewerAccountType != null)
            'viewerAccountType': viewerAccountType.name,
        });
        final uid = result.data is Map ? result.data['uid'] as String? : null;
        return uid;
      } catch (_) {}
    }
    return _createInstitutionUserOnClient(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      classIds: classIds,
      studentIds: studentIds,
      fatherPhone: fatherPhone,
      motherPhone: motherPhone,
      alternativePhone: alternativePhone,
      viewerAccountType: viewerAccountType,
      previousPassword: previousPassword,
    );
  }

  /// Deletes Auth for [uid]. Fails if the Auth account cannot be removed so
  /// recreate-with-same-email cannot leave a stale login behind.
  Future<void> deleteInstitutionAuthUser({
    required String uid,
    required String email,
    String? passwordForAuthCleanup,
  }) async {
    if (uid == _auth.currentUser?.uid) {
      throw StateError('You cannot delete the account you are signed in with.');
    }
    if (AppConfig.useCloudFunctions) {
      try {
        await FirebaseFunctions.instance.httpsCallable('deleteInstitutionUser').call({
          'uid': uid,
        });
        return;
      } catch (_) {
        // Fall through to Spark client Auth delete.
      }
    }
    final password = passwordForAuthCleanup;
    if (password == null || password.isEmpty) {
      throw StateError(
        'Enter the current password for $email to permanently delete their '
        'Firebase login. Without that, recreating this email will fail.',
      );
    }
    if (email.isEmpty) {
      throw StateError('Cannot delete Auth user without an email.');
    }
    final app = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await secondaryAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final signedInUid = cred.user?.uid;
      if (signedInUid != null && signedInUid != uid) {
        throw StateError(
          'Signed in as a different account than the profile being deleted.',
        );
      }
      await cred.user?.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }
      if (error.code == 'invalid-credential' ||
          error.code == 'wrong-password' ||
          error.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw StateError(
          'Wrong password for $email. Auth was not deleted. '
          'Try again with the current password, or remove the user in '
          'Firebase Console → Authentication.',
        );
      }
      rethrow;
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Future<String> _createInstitutionUserOnClient({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    List<String> classIds = const [],
    List<String> studentIds = const [],
    String fatherPhone = '',
    String motherPhone = '',
    String alternativePhone = '',
    ViewerAccountType? viewerAccountType,
    String? previousPassword,
  }) async {
    if (_auth.currentUser == null) {
      throw StateError('Admin must be signed in.');
    }
    final app = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);
    try {
      UserCredential cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        // Auth user survived a Firestore-only delete. Re-enroll and align the
        // temporary password with what the admin just entered.
        final signedInWith = previousPassword ?? password;
        cred = await _signInExistingForReenroll(
          secondaryAuth: secondaryAuth,
          email: email,
          password: signedInWith,
          forNewPassword: password,
        );
        if (signedInWith != password) {
          await cred.user!.updatePassword(password);
        }
      }
      final uid = cred.user?.uid;
      if (uid == null) {
        throw StateError('Could not create the account.');
      }
      final existingProfile =
          await InstitutionPaths(kDefaultInstitutionId).users.doc(uid).get();
      if (existingProfile.exists) {
        throw StateError(
          'This email is already enrolled. Edit or delete the existing user first.',
        );
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
        'mustChangePassword': role == UserRole.teacher ||
            role == UserRole.floorIncharge ||
            role == UserRole.viewer,
        if (viewerAccountType != null)
          'viewerAccountType': viewerAccountType.name,
        // Parent enrollment always persists all three phones (alternative may be '').
        if (fatherPhone.isNotEmpty || motherPhone.isNotEmpty) ...{
          'fatherPhone': fatherPhone,
          'motherPhone': motherPhone,
          'alternativePhone': alternativePhone,
        },
      });
      return uid;
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Future<UserCredential> _signInExistingForReenroll({
    required FirebaseAuth secondaryAuth,
    required String email,
    required String password,
    required String forNewPassword,
  }) async {
    try {
      return await secondaryAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (!_isInvalidPassword(error)) rethrow;
      if (password == forNewPassword) {
        // Admin entered only the new temp password; Auth still has another one.
        throw AuthReenrollPasswordNeeded(email);
      }
      throw StateError(
        'The previous password for $email is incorrect. '
        'Check it, or delete that Auth user in Firebase Console → Authentication.',
      );
    }
  }

  bool _isInvalidPassword(FirebaseAuthException error) {
    return error.code == 'invalid-credential' ||
        error.code == 'wrong-password' ||
        error.code == 'INVALID_LOGIN_CREDENTIALS';
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

  /// First-login / mandatory password change after a successful email sign-in.
  ///
  /// Always requires the temporary password (from sign-in memory or the form)
  /// and rejects reusing it. Reauthenticates with that temporary password, then
  /// updates Auth, then clears `mustChangePassword`.
  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in first.');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('Signed-in account has no email.');
    }
    final temporaryPassword = currentPassword ?? _pendingTemporaryPassword;
    validateFirstLoginNewPassword(
      newPassword: newPassword,
      temporaryPassword: temporaryPassword,
    );
    // temporaryPassword is non-null/non-empty after validation.
    final temp = temporaryPassword!;
    final cred = EmailAuthProvider.credential(
      email: email,
      password: temp,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
    await InstitutionPaths(kDefaultInstitutionId).users.doc(user.uid).update({
      'mustChangePassword': false,
    });
    clearTemporaryPasswordMemory();
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

/// Auth still has this email (usually after a Firestore-only delete), but the
/// new temporary password does not match. UI should ask for the current password.
class AuthReenrollPasswordNeeded implements Exception {
  AuthReenrollPasswordNeeded(this.email);
  final String email;

  @override
  String toString() =>
      'A Firebase login for $email already exists with a different password.';
}
