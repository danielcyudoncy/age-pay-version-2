import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';

class MemberRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'members';

  MemberRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<MemberModel>> getMembers() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MemberModel.fromFirestore(doc)).toList());
  }

  Future<MemberModel?> getMemberById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return MemberModel.fromFirestore(doc);
    }
    return null;
  }

  Future<MemberModel?> getMemberByUserId(String userId) async {
    final snapshot =
        await _collection.where('userId', isEqualTo: userId).limit(1).get();
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
    await _collection.doc(member.id).update(
      member.copyWith(updatedAt: DateTime.now()).toFirestore(),
    );
  }

  Future<void> deleteMember(String id) async {
    await _collection.doc(id).update({'isActive': false});
  }

  Future<List<MemberModel>> searchMembers(String query) async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .get();

    final queryLower = query.toLowerCase();
    return snapshot.docs
        .map((doc) => MemberModel.fromFirestore(doc))
        .where((m) =>
            m.fullName.toLowerCase().contains(queryLower) ||
            m.email.toLowerCase().contains(queryLower) ||
            m.phoneNumber.contains(query))
        .toList();
  }
}
