import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/obligation_model.dart';
import '../../core/constants/enums.dart';

class ObligationRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'obligations';

  ObligationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<ObligationModel>> getAllObligations() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ObligationModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ObligationModel>> getMemberObligations(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ObligationModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .where('status', whereIn: ['unpaid', 'partial'])
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ObligationModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ObligationModel>> getLevyObligations(String levyId) {
    return _collection
        .where('levyId', isEqualTo: levyId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ObligationModel.fromFirestore(doc))
            .toList());
  }

  Future<ObligationModel?> getObligationById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return ObligationModel.fromFirestore(doc);
    return null;
  }

  Future<String> createObligation(ObligationModel obligation) async {
    final docRef = _collection.doc();
    final newObligation = obligation.copyWith(
      id: docRef.id,
      outstandingBalance: obligation.amount,
    );
    await docRef.set(newObligation.toFirestore());
    return docRef.id;
  }

  Future<void> updateObligationStatus(
    String id, {
    double? paidAmount,
    double? outstandingBalance,
    ObligationStatus? status,
    DateTime? settledAt,
  }) async {
    final updates = <String, dynamic>{};
    if (paidAmount != null) updates['paidAmount'] = paidAmount;
    if (outstandingBalance != null) updates['outstandingBalance'] = outstandingBalance;
    if (status != null) updates['status'] = status.name;
    if (settledAt != null) updates['settledAt'] = Timestamp.fromDate(settledAt);
    await _collection.doc(id).update(updates);
  }

  Future<void> batchCreateObligations(List<ObligationModel> obligations) async {
    final batch = _firestore.batch();
    for (final obligation in obligations) {
      final docRef = _collection.doc();
      final newObligation = obligation.copyWith(
        id: docRef.id,
        outstandingBalance: obligation.amount,
      );
      batch.set(docRef, newObligation.toFirestore());
    }
    await batch.commit();
  }

  Future<void> batchCreateFromMaps(List<Map<String, dynamic>> maps) async {
    final batch = _firestore.batch();
    for (final map in maps) {
      final docRef = _collection.doc();
      final data = {...map};
      data['id'] = docRef.id;
      if (!data.containsKey('outstandingBalance')) {
        data['outstandingBalance'] = data['amount'] ?? 0;
      }
      batch.set(docRef, data);
    }
    await batch.commit();
  }
}
