import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/models/user_model.dart';
import '../../../core/constants/enums.dart';

class AdminUserRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'users';

  AdminUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<UserModel>> getUsersStream() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<UserModel>> getUsers() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateUserRole(
    String uid, {
    required UserRole role,
    UserRole? nationalRole,
    bool clearNationalRole = false,
  }) async {
    final Map<String, dynamic> updates = {
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (clearNationalRole) {
      updates['nationalRole'] = FieldValue.delete();
    } else if (nationalRole != null) {
      updates['nationalRole'] = nationalRole.name;
    }
    await _collection.doc(uid).update(updates);
  }

  Future<void> updateUserStatus(
    String uid, {
    required bool isActive,
    AccountStatus? status,
  }) async {
    final Map<String, dynamic> updates = {
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status != null) {
      updates['status'] = status.name;
    }
    await _collection.doc(uid).update(updates);
  }

  Future<void> reassignUserBranch(
    String uid, {
    required String organizationId,
    required String branchId,
    required String branchName,
  }) async {
    await _collection.doc(uid).update({
      'organizationId': organizationId,
      'branchId': branchId,
      'branchName': branchName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleSuperAdmin(String uid, bool isSuperAdmin) async {
    await _collection.doc(uid).update({
      'role': isSuperAdmin ? UserRole.superAdmin.name : UserRole.member.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
