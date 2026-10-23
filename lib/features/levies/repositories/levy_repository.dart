import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/levy_model.dart';

class LevyRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'levies';

  LevyRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<LevyModel>> getActiveLevies() {
    return getAllLevies().map(
      (levies) => levies.where((l) => l.isActive).toList(),
    );
  }

  Stream<List<LevyModel>> getAllLevies() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection.snapshots().map(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => LevyModel.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      },
    ).handleError((_) => <LevyModel>[]);
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
    await _collection
        .doc(levy.id)
        .update(levy.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> deactivateLevy(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
