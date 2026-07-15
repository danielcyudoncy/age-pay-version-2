import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../../core/constants/enums.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';
import '../../obligations/repositories/obligation_repository.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email. Please sign in instead.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      case 'user-not-found':
        return 'No account found for this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = result.user;
      if (firebaseUser != null) {
        return await _loadOrCreateProfile(firebaseUser);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Login failed. Please try again.');
    }
  }

  /// Reads the user's profile doc. If it is missing (for example the
  /// Firestore write during registration was blocked), a basic profile is
  /// created from the Firebase Auth user so the sign-in can still complete.
  Future<UserModel?> _loadOrCreateProfile(User firebaseUser) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) return UserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException(
          'Profile could not be loaded because the request was denied. '
          'If App Check is enabled, register the debug token.',
        );
      }
    }

    final fallback = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      phoneNumber: '',
      role: UserRole.member,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(fallback.toFirestore());
      return fallback;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException(
          'Your profile is missing and could not be recreated. '
          'Please contact support.',
        );
      }
      throw AuthException('Login failed. Please try again.');
    } catch (e) {
      throw AuthException('Login failed. Please try again.');
    }
  }

  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required UserRole role,
    DateTime? dateOfBirth,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = result.user;
      if (firebaseUser == null) return null;

      // The freshly created user must force-refresh its ID token before the
      // first Firestore write. Without this, the Firestore SDK may send the
      // request with a stale token where request.auth is null, causing the
      // security rules to deny the write with PERMISSION_DENIED.
      await firebaseUser.getIdToken(true);

      final user = UserModel(
        uid: firebaseUser.uid,
        email: email,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: role,
        createdAt: DateTime.now(),
      );

      await _writeWithAuthRetry(
        () => _firestore
            .collection('users')
            .doc(user.uid)
            .set(user.toFirestore()),
      );

      final member = MemberModel(
        id: '',
        userId: user.uid,
        fullName: displayName,
        email: email,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth ?? DateTime(2000),
        joinedDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final memberRepo = MemberRepository(firestore: _firestore);
      final memberId = await memberRepo.createMember(member);

      final obligationRepo = ObligationRepository(firestore: _firestore);
      await obligationRepo.backfillObligationsForNewMember(memberId);

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException(
          'Registration was blocked by database security rules. '
          'Ensure the Firestore rules are deployed and that this role can be self-registered.',
        );
      }
      throw AuthException('Registration failed: ${e.message ?? e.toString()}');
    } catch (e) {
      throw AuthException('Registration failed. Please try again.');
    }
  }

  /// Runs a Firestore write and retries once after force-refreshing the ID
  /// token if the request was denied because request.auth was not yet
  /// populated for the newly created user.
  Future<void> _writeWithAuthRetry(Future<void> Function() write) async {
    try {
      await write();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final user = _auth.currentUser;
        if (user != null) {
          await user.getIdToken(true);
          await write();
          return;
        }
      }
      rethrow;
    }
  }

  Future<UserModel?> _getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException(
          'Profile could not be loaded. If App Check is enabled, '
          'register the debug token in the Firebase Console.',
        );
      }
      throw AuthException('Could not load your profile. Please try again.');
    } catch (e) {
      throw AuthException('Could not load your profile. Please try again.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await _getUserData(user.uid);
    }
    return null;
  }
}
