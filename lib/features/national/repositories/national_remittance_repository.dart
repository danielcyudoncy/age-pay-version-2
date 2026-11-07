import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/national_remittance_model.dart';

class NationalRemittanceRepository {
  final FirebaseFirestore _firestore;
  static const String collection = 'national_remittances';

  NationalRemittanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<NationalRemittanceModel>> getRemittances({
    required String organizationId,
    String? branchId,
  }) async* {
    if (organizationId.isEmpty) {
      yield [];
      return;
    }

    Query query = _collection.where('organizationId', isEqualTo: organizationId);

    if (branchId != null && branchId.isNotEmpty && branchId != 'national') {
      query = query.where('branchId', isEqualTo: branchId);
    }

    try {
      await for (final snapshot in query.snapshots()) {
        final list = snapshot.docs
            .map((doc) => NationalRemittanceModel.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } catch (_) {
      yield [];
    }
  }

  Future<String> recordRemittance(NationalRemittanceModel record) async {
    final docRef = _collection.doc();
    final now = DateTime.now();
    final newRecord = record.copyWith(
      id: docRef.id,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(newRecord.toFirestore());
    return docRef.id;
  }

  Future<void> updateRemittance(NationalRemittanceModel record) async {
    await _collection.doc(record.id).update({
      ...record.toFirestore(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
