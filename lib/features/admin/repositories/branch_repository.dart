import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch_model.dart';

class BranchRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'branches';

  BranchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<BranchModel>> getBranches(String organizationId) {
    if (organizationId.isEmpty) return Stream.value([]);
    return _collection
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BranchModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<BranchModel>> getBranchesFuture(String organizationId) async {
    if (organizationId.isEmpty) return [];
    final snapshot = await _collection
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => BranchModel.fromFirestore(doc)).toList();
  }

  Future<BranchModel?> getBranchById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return BranchModel.fromFirestore(doc);
    }
    return null;
  }

  Future<String> createBranch(BranchModel branch) async {
    final docRef = _collection.doc();
    final newBranch = branch.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(newBranch.toFirestore());
    return docRef.id;
  }

  Future<void> updateBranch(BranchModel branch) async {
    await _collection
        .doc(branch.id)
        .update(branch.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> deleteBranch(String id) async {
    await _collection.doc(id).delete();
  }
}
