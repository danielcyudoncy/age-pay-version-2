import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';
import '../models/cash_handover_model.dart';

class CashHandoverRepository {
  final FirebaseFirestore _firestore;
  static const String collection = 'cash_handovers';

  CashHandoverRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<CashHandoverModel>> getHandovers({
    required String organizationId,
    String? branchId,
  }) async* {
    if (organizationId.isEmpty) {
      yield [];
      return;
    }

    Query query = _collection.where('organizationId', isEqualTo: organizationId);

    if (branchId != null && branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    try {
      await for (final snapshot in query.snapshots()) {
        final list = snapshot.docs
            .map((doc) => CashHandoverModel.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.handedOverAt.compareTo(a.handedOverAt));
        yield list;
      }
    } catch (_) {
      yield [];
    }
  }

  Stream<List<CashHandoverModel>> getPendingHandovers({
    required String organizationId,
    String? branchId,
  }) async* {
    if (organizationId.isEmpty) {
      yield [];
      return;
    }

    Query query = _collection
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: CashHandoverStatus.pending.name);

    if (branchId != null && branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    try {
      await for (final snapshot in query.snapshots()) {
        final list = snapshot.docs
            .map((doc) => CashHandoverModel.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.handedOverAt.compareTo(a.handedOverAt));
        yield list;
      }
    } catch (_) {
      yield [];
    }
  }

  Future<String> createHandover(CashHandoverModel handover) async {
    final docRef = _collection.doc();
    final now = DateTime.now();
    final newHandover = handover.copyWith(
      id: docRef.id,
      status: CashHandoverStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(newHandover.toFirestore());
    return docRef.id;
  }

  Future<void> acceptHandover({
    required String handoverId,
    required String receivedBy,
    required String receivedById,
    String? bankName,
    String? bankAccountNumber,
    String? depositSlipUrl,
    String? notes,
  }) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'status': CashHandoverStatus.accepted.name,
      'receivedBy': receivedBy,
      'receivedById': receivedById,
      'acknowledgedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
    if (bankName != null) data['bankName'] = bankName;
    if (bankAccountNumber != null) data['bankAccountNumber'] = bankAccountNumber;
    if (depositSlipUrl != null) data['depositSlipUrl'] = depositSlipUrl;
    if (notes != null) data['notes'] = notes;

    await _collection.doc(handoverId).update(data);
  }

  Future<void> rejectHandover({
    required String handoverId,
    required String receivedBy,
    required String receivedById,
    required String reason,
  }) async {
    final now = DateTime.now();
    await _collection.doc(handoverId).update({
      'status': CashHandoverStatus.rejected.name,
      'receivedBy': receivedBy,
      'receivedById': receivedById,
      'acknowledgedAt': Timestamp.fromDate(now),
      'notes': reason,
      'updatedAt': Timestamp.fromDate(now),
    });
  }
}
