import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../../core/constants/enums.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';
import '../../obligations/repositories/obligation_repository.dart';
import '../models/co_founder_invitation_model.dart';
import '../repositories/co_founder_invitation_repository.dart';

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
      organizationId: firebaseUser.uid,
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
    required String organizationId,
    DateTime? dateOfBirth,
    String? branchId,
    String? branchName,
    bool isNewOrganization = false,
    String? newOrganizationName,
    String? newBranchName,
    String? coFounderName,
    String? coFounderPhone,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = result.user;
      if (firebaseUser == null) return null;

      // The freshly created user must force-refresh its ID token before the
      // first Firestore write.
      await firebaseUser.getIdToken(true);

      String finalOrgId = organizationId;
      String? finalBranchId = branchId;
      String? finalBranchName = branchName;

      // 1. If registering a new Age Grade
      if (isNewOrganization && newOrganizationName != null && newOrganizationName.isNotEmpty) {
        final orgDoc = _firestore.collection('organizations').doc();
        finalOrgId = orgDoc.id;
        await _writeWithAuthRetry(() => orgDoc.set({
          'name': newOrganizationName,
          'slug': newOrganizationName.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
          'description': '',
          'contactEmail': email,
          'contactPhone': phoneNumber,
          'address': '',
          'isActive': false, // Inactive until co-founder verification
          'openForJoin': false,
          'memberCount': 1,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }));

        final effectiveBranchName = (newBranchName != null && newBranchName.isNotEmpty)
            ? newBranchName
            : 'Headquarters / Main Branch';
        final branchDoc = _firestore.collection('branches').doc();
        finalBranchId = branchDoc.id;
        finalBranchName = effectiveBranchName;

        await _writeWithAuthRetry(() => branchDoc.set({
          'organizationId': finalOrgId,
          'name': effectiveBranchName,
          'state': '',
          'city': '',
          'presidentId': firebaseUser.uid,
          'presidentName': displayName,
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }));

        if (coFounderPhone != null && coFounderPhone.isNotEmpty) {
          final coFounderRepo =
              CoFounderInvitationRepository(firestore: _firestore);
          await coFounderRepo.createInvitation(CoFounderInvitationModel(
            id: '',
            organizationId: finalOrgId,
            organizationName: newOrganizationName,
            branchName: effectiveBranchName,
            presidentUid: firebaseUser.uid,
            presidentName: displayName,
            presidentPhone: phoneNumber,
            secretaryName: coFounderName ?? 'General Secretary',
            secretaryPhone: coFounderPhone,
            status: 'pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      } else if (newBranchName != null && newBranchName.isNotEmpty) {
        // Adding a new branch under an existing organization
        final branchDoc = _firestore.collection('branches').doc();
        finalBranchId = branchDoc.id;
        finalBranchName = newBranchName;
        await _writeWithAuthRetry(() => branchDoc.set({
          'organizationId': finalOrgId,
          'name': newBranchName,
          'state': '',
          'city': '',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }));
      }

      // 2. Determine initial status and effective role
      // All self-registrations require approval (either via co-founder verification or branch executive approval)
      final effectiveRole = isNewOrganization ? UserRole.president : UserRole.member;
      final requestedRole = isNewOrganization ? UserRole.president : role;
      const initialStatus = AccountStatus.pendingApproval;

      final user = UserModel(
        uid: firebaseUser.uid,
        organizationId: finalOrgId,
        email: email,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: effectiveRole,
        requestedRole: requestedRole,
        status: initialStatus,
        branchId: finalBranchId,
        branchName: finalBranchName,
        coFounderName: coFounderName,
        coFounderPhone: coFounderPhone,
        createdAt: DateTime.now(),
        isActive: false, // Inactive pending approval
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
        branchId: finalBranchId,
        branchName: finalBranchName,
        status: 'pending_approval',
        isActive: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final memberRepo = MemberRepository(firestore: _firestore);
      await memberRepo.createMember(member);

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthException(
          'Registration was blocked by database security rules. '
          'Ensure the Firestore rules are deployed.',
        );
      }
      throw AuthException('Registration failed: ${e.message ?? e.toString()}');
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  Stream<List<UserModel>> getPendingRegistrations(String organizationId) {
    if (organizationId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: AccountStatus.pendingApproval.name)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => UserModel.fromFirestore(d)).toList())
        .handleError((_) => <UserModel>[]);
  }

  Future<void> approveUserRegistration({
    required String uid,
    required String organizationId,
  }) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return;
    final user = UserModel.fromFirestore(userDoc);
    final approvedRole = user.requestedRole ?? user.role;

    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'status': AccountStatus.approved.name,
      'role': approvedRole.name,
      'isActive': true,
    });

    final membersSnap = await _firestore
        .collection('members')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    String? memberId;
    if (membersSnap.docs.isNotEmpty) {
      memberId = membersSnap.docs.first.id;
      batch.update(membersSnap.docs.first.reference, {
        'status': 'approved',
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();

    // Automatically reconcile obligations upon approval
    if (memberId != null) {
      final obligationRepo = ObligationRepository(firestore: _firestore);
      await obligationRepo.reconcileMemberObligations(
        memberId,
        userId: uid,
      );
    }
  }

  Future<void> rejectUserRegistration({
    required String uid,
  }) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'status': AccountStatus.rejected.name,
      'isActive': false,
    });

    final membersSnap = await _firestore
        .collection('members')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (membersSnap.docs.isNotEmpty) {
      batch.update(membersSnap.docs.first.reference, {
        'status': 'rejected',
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
  }

  /// Returns the organizationId for a new member by reusing the existing
  /// organization in this single-organization teaching app. It looks up the
  /// first secretary or admin and uses their organizationId so the member
  /// shares the same tenant as the announcements they should receive.
  Future<String> getActiveOrganizationId() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return '';

    final currentDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (currentDoc.exists) {
      final data = currentDoc.data()!;
      final orgId = data['organizationId'];
      if (orgId is String && orgId.isNotEmpty) return orgId;
    }

    final snapshot = await _firestore
        .collection('users')
        .where('role', whereIn: [
          'secretary',
          'viceSecretary',
          'superAdmin',
          'president',
          'vicePresident',
        ])
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final orgId = data['organizationId'];
      if (orgId is String && orgId.isNotEmpty) return orgId;
      return snapshot.docs.first.id;
    }
    return currentUser.uid;
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
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await _getUserData(user.uid);
      }
      return null;
    } catch (_) {
      try {
        await _auth.signOut();
      } catch (_) {}
      return null;
    }
  }
}
