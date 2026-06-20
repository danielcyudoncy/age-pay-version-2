import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/levy_model.dart';

class LevyRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'levies';

  LevyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<LevyModel>> getActiveLevies() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LevyModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<LevyModel>> getAllLevies() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LevyModel.fromFirestore(doc))
            .toList());
  }

  Future<LevyModel?> getLevyById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return LevyModel.fromFirestore(doc);
    return null;
  }

  Future<String> createLevy(LevyModel levy) async {
    final docRef = _collection.doc();
    final newLevy = levy.copyWith(id: docRef.id);
    await docRef.set(newLevy.toFirestore());
    return docRef.id;
  }

  Future<void> updateLevy(LevyModel levy) async {
    await _collection.doc(levy.id).update(
      levy.copyWith(updatedAt: DateTime.now()).toFirestore(),
    );
  }

  Future<void> deactivateLevy(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
