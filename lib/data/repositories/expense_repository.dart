import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'expenses';

  ExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<ExpenseModel>> getExpenses() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ExpenseModel>> getExpensesByDateRange(DateTime start, DateTime end) {
    return _collection
        .where('expenseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('expenseDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc))
            .toList());
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return ExpenseModel.fromFirestore(doc);
    return null;
  }

  Future<String> createExpense(ExpenseModel expense) async {
    final docRef = _collection.doc();
    final newExpense = expense.copyWith(id: docRef.id);
    await docRef.set(newExpense.toFirestore());
    return docRef.id;
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _collection.doc(expense.id).update(
      expense.copyWith(updatedAt: DateTime.now()).toFirestore(),
    );
  }

  Future<void> deleteExpense(String id) async {
    await _collection.doc(id).delete();
  }
}
