import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt_model.dart';

class ReceiptRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'receipts';

  ReceiptRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<ReceiptModel>> getMemberReceipts(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReceiptModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ReceiptModel>> getReceiptsByDateRange(DateTime start, DateTime end) {
    return _collection
        .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReceiptModel.fromFirestore(doc))
            .toList());
  }

  Future<ReceiptModel?> getReceiptById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return ReceiptModel.fromFirestore(doc);
    return null;
  }

  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async {
    final snapshot =
        await _collection.where('paymentId', isEqualTo: paymentId).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return ReceiptModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<String> createReceipt(ReceiptModel receipt) async {
    final docRef = _collection.doc();
    final newReceipt = receipt.copyWith(id: docRef.id);
    await docRef.set(newReceipt.toFirestore());
    return docRef.id;
  }
}