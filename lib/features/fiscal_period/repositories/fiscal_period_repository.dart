import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fiscal_period_model.dart';

class FiscalPeriodRepository {
  final FirebaseFirestore _firestore;
  static const String collection = 'fiscal_periods';

  FiscalPeriodRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<FiscalPeriodModel>> getFiscalPeriods({
    required String organizationId,
    String? branchId,
  }) async* {
    if (organizationId.isEmpty) {
      yield [];
      return;
    }

    Query query = _collection
        .where('organizationId', isEqualTo: organizationId);

    if (branchId != null && branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    try {
      await for (final snapshot in query.snapshots()) {
        final list = snapshot.docs
            .map((doc) => FiscalPeriodModel.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.startDate.compareTo(a.startDate));
        yield list;
      }
    } catch (_) {
      yield [];
    }
  }

  Future<FiscalPeriodModel?> getActiveFiscalPeriod({
    required String organizationId,
    String? branchId,
  }) async {
    if (organizationId.isEmpty) return null;

    Query query = _collection
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true);

    if (branchId != null && branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    final snap = await query.limit(1).get();
    if (snap.docs.isEmpty) return null;
    return FiscalPeriodModel.fromFirestore(snap.docs.first);
  }

  Future<String> createFiscalPeriod(FiscalPeriodModel period) async {
    final docRef = _collection.doc();
    final now = DateTime.now();
    final newPeriod = period.copyWith(
      id: docRef.id,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(newPeriod.toFirestore());
    return docRef.id;
  }

  Future<void> updateFiscalPeriod(FiscalPeriodModel period) async {
    await _collection.doc(period.id).update({
      ...period.toFirestore(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<FiscalPeriodModel?> getFiscalPeriodById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return FiscalPeriodModel.fromFirestore(doc);
  }
}
