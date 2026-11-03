import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/member_model.dart';

class MemberRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'members';

  MemberRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<MemberModel>> getMembers() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemberModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <MemberModel>[]);
  }

  /// Returns all members including active and suspended/inactive records.
  Stream<List<MemberModel>> getAllMembers() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemberModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <MemberModel>[]);
  }

  Future<MemberModel?> getMemberById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return MemberModel.fromFirestore(doc);
    }
    return null;
  }

  Future<MemberModel?> getMemberByUserId(String userId) async {
    final snapshot = await _collection
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return MemberModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<String> createMember(MemberModel member) async {
    final docRef = _collection.doc();
    final newMember = member.copyWith(id: docRef.id);
    await docRef.set(newMember.toFirestore());
    return docRef.id;
  }

  Future<void> updateMember(MemberModel member) async {
    await _collection
        .doc(member.id)
        .update(member.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  /// Checks how many payment records are associated with this member.
  /// Used for financial integrity checks prior to deletion.
  Future<int> getMemberPaymentCount(String memberId, {String? userId}) async {
    try {
      final byMemberSnapshot = await _firestore
          .collection('payments')
          .where('memberId', isEqualTo: memberId)
          .limit(1)
          .get();
      if (byMemberSnapshot.docs.isNotEmpty) {
        return byMemberSnapshot.docs.length;
      }

      if (userId != null && userId.isNotEmpty) {
        final byUserSnapshot = await _firestore
            .collection('payments')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        return byUserSnapshot.docs.length;
      }
    } catch (_) {
      // In case collection query fails, return 0
    }
    return 0;
  }

  /// Soft deletes a member by marking isActive: false (Archival).
  /// Retains financial ledger history while disabling account access.
  Future<void> softDeleteMember(String id, {String? userId}) async {
    final now = DateTime.now();
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(now),
    });

    if (userId != null && userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'accountStatus': 'suspended',
        'updatedAt': Timestamp.fromDate(now),
      });
    }
  }

  /// Permanently removes the member, obligations, and matching user doc.
  /// Only allowed when no payment history exists.
  Future<void> purgeMemberPermanently(String id, {String? userId}) async {
    // 1. Delete member document
    await _collection.doc(id).delete();

    // 2. Delete member obligations
    try {
      final obligations = await _firestore
          .collection('obligations')
          .where('memberId', isEqualTo: id)
          .get();
      for (final doc in obligations.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    // 3. Delete user document if linked
    if (userId != null && userId.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(userId).delete();
      } catch (_) {}
    }
  }

  /// Backward-compatible alias for soft delete.
  Future<void> deleteMember(String id) async {
    await softDeleteMember(id);
  }

  /// Sets whether a branch member is enrolled in the national branch.
  /// Only branch presidents (or superAdmin) can enroll a member into the national tier.
  Future<void> setNationalEnrollment({
    required String memberId,
    required bool isEnrolled,
    required String byUserId,
  }) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'isEnrolledInNational': isEnrolled,
      'enrolledInNationalAt': isEnrolled ? Timestamp.fromDate(now) : null,
      'enrolledInNationalBy': isEnrolled ? byUserId : null,
      'updatedAt': Timestamp.fromDate(now),
    };

    await _collection.doc(memberId).update(updates);

    // Synchronize to users collection if matching user exists
    final memberDoc = await _collection.doc(memberId).get();
    if (memberDoc.exists) {
      final member = MemberModel.fromFirestore(memberDoc);
      if (member.userId.isNotEmpty) {
        final userUpdates = <String, dynamic>{
          'isEnrolledInNational': isEnrolled,
          'enrolledInNationalAt': isEnrolled ? Timestamp.fromDate(now) : null,
          'enrolledInNationalBy': isEnrolled ? byUserId : null,
        };
        await _firestore
            .collection('users')
            .doc(member.userId)
            .update(userUpdates);
      }
    }
  }

  Future<List<MemberModel>> searchMembers(String query) async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .get();

    final queryLower = query.toLowerCase();
    return snapshot.docs
        .map((doc) => MemberModel.fromFirestore(doc))
        .where(
          (m) =>
              m.fullName.toLowerCase().contains(queryLower) ||
              m.email.toLowerCase().contains(queryLower) ||
              m.phoneNumber.contains(query),
        )
        .toList();
  }
}
