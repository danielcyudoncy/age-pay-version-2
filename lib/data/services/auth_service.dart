import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/models/user_model.dart';
import '../../core/constants/enums.dart';
import '../../data/models/member_model.dart';
import '../../data/repositories/member_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        return await _getUserData(result.user!.uid);
      }
      return null;
    } catch (e) {
      throw Exception('Login failed: $e');
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
      if (result.user != null) {
        final user = UserModel(
          uid: result.user!.uid,
          email: email,
          displayName: displayName,
          phoneNumber: phoneNumber,
          role: role,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(user.toFirestore());

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
        await memberRepo.createMember(member);

        return user;
      }
      return null;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<UserModel?> _getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
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
