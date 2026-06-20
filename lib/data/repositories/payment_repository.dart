import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../../core/constants/enums.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'payments';

  PaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<PaymentModel>> getMemberPayments(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<PaymentModel>> getPendingPayments() {
    return _collection
        .where('status', isEqualTo: PaymentStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  Future<PaymentModel?> getPaymentById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return PaymentModel.fromFirestore(doc);
    return null;
  }

  Future<String> createPayment(PaymentModel payment) async {
    final docRef = _collection.doc();
    final newPayment = payment.copyWith(id: docRef.id);
    await docRef.set(newPayment.toFirestore());
    return docRef.id;
  }

  Future<void> updatePaymentStatus(
    String id, {
    required PaymentStatus status,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? receiptUrl,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
    };
    if (verifiedBy != null) updates['verifiedBy'] = verifiedBy;
    if (verifiedAt != null) updates['verifiedAt'] = Timestamp.fromDate(verifiedAt);
    if (receiptUrl != null) updates['receiptUrl'] = receiptUrl;
    await _collection.doc(id).update(updates);
  }

  Future<void> updatePaymentAllocations(
    String id,
    List<PaymentAllocationModel> allocations,
  ) async {
    await _collection.doc(id).update({
      'allocations': allocations.map((a) => a.toMap()).toList(),
    });
  }

  Stream<List<PaymentModel>> getAllPayments() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }
}
