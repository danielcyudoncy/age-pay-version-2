import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/enums.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'expenses';

  ExpenseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<ExpenseModel>> getExpenses() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <ExpenseModel>[]);
  }

  Stream<List<ExpenseModel>> getPendingExpenses() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('status', isEqualTo: ExpenseStatus.pendingApproval.name)
        .snapshots()
        .map(
          (snapshot) {
            final list = snapshot.docs
                .map((doc) => ExpenseModel.fromFirestore(doc))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          },
        )
        .handleError((_) => <ExpenseModel>[]);
  }

  Stream<List<ExpenseModel>> getApprovedExpenses() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('status', isEqualTo: ExpenseStatus.approved.name)
        .snapshots()
        .map(
          (snapshot) {
            final list = snapshot.docs
                .map((doc) => ExpenseModel.fromFirestore(doc))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          },
        )
        .handleError((_) => <ExpenseModel>[]);
  }

  Stream<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('expenseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('expenseDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <ExpenseModel>[]);
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return ExpenseModel.fromFirestore(doc);
    return null;
  }

  Future<String> createExpense(ExpenseModel expense) async {
    final docRef = _collection.doc();
    final newExpense = expense.copyWith(
      id: docRef.id,
      status: ExpenseStatus.pendingApproval,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(newExpense.toFirestore());

    // Notify President, Financial Secretary, and Secretary of pending approval
    try {
      final notifDoc = _firestore.collection('notifications').doc();
      await notifDoc.set({
        'id': notifDoc.id,
        'organizationId': expense.organizationId,
        'title': 'New Expense Awaiting Approval',
        'body': '₦${expense.amount.toStringAsFixed(0)} for "${expense.title}" requires your executive sign-off.',
        'type': 'expense_approval_required',
        'payload': docRef.id,
        'targetRole': 'executive',
        'read': false,
        'receivedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}

    return docRef.id;
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _collection
        .doc(expense.id)
        .update(expense.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  /// Records an approval from an executive (President, Financial Secretary, or Secretary).
  /// When all 3 required roles have approved, the expense automatically transitions to `approved`.
  Future<void> approveExpense({
    required String expenseId,
    required UserRole role,
    required String userId,
    required String userName,
  }) async {
    final key = ExpenseModel.roleToApprovalKey(role);
    if (key == null) {
      throw ArgumentError(
        'Only President, Financial Secretary, or Secretary can approve expenses.',
      );
    }

    final docRef = _collection.doc(expenseId);
    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Expense record not found.');
    }

    final current = ExpenseModel.fromFirestore(doc);
    if (current.status == ExpenseStatus.rejected) {
      throw Exception('Cannot approve a rejected expense.');
    }

    final updatedApprovals = Map<String, dynamic>.from(current.approvals);
    updatedApprovals[key] = {
      'approved': true,
      'by': userId,
      'byName': userName,
      'role': role.name,
      'at': Timestamp.fromDate(DateTime.now()),
    };

    final tempExpense = current.copyWith(approvals: updatedApprovals);
    final isNowFullyApproved = tempExpense.isFullyApproved;
    final now = DateTime.now();

    await docRef.update({
      'approvals': updatedApprovals,
      if (isNowFullyApproved) 'status': ExpenseStatus.approved.name,
      'updatedAt': Timestamp.fromDate(now),
    });

    if (isNowFullyApproved) {
      try {
        final notifDoc = _firestore.collection('notifications').doc();
        await notifDoc.set({
          'id': notifDoc.id,
          'organizationId': current.organizationId,
          'title': 'Expense Fully Approved!',
          'body': 'Expense "${current.title}" (₦${current.amount.toStringAsFixed(0)}) is signed off by all 3 executives and deducted from funds.',
          'type': 'expense_approved',
          'payload': expenseId,
          'targetUserId': current.createdBy,
          'read': false,
          'receivedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
        });
      } catch (_) {}
    }
  }

  /// Rejects an expense with an executive reason.
  Future<void> rejectExpense({
    required String expenseId,
    required UserRole role,
    required String userId,
    required String userName,
    required String reason,
  }) async {
    final now = DateTime.now();
    await _collection.doc(expenseId).update({
      'status': ExpenseStatus.rejected.name,
      'rejectionReason': reason,
      'rejectedBy': userName,
      'rejectedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Future<void> deleteExpense(String id) async {
    await _collection.doc(id).delete();
  }
}
