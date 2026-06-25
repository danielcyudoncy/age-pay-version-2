import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/enums.dart';
import '../data/models/member_model.dart';
import '../data/models/payment_model.dart';
import '../data/models/obligation_model.dart';
import '../data/models/levy_model.dart';
import '../data/models/expense_model.dart';
import '../data/models/receipt_model.dart';
import '../data/repositories/member_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/obligation_repository.dart';
import '../data/repositories/levy_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/receipt_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/payment_service.dart';
import '../features/auth/models/user_model.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/obligations/providers/obligation_provider.dart';
import '../features/levies/providers/levy_provider.dart' as levy_provider
    show levyRepositoryProvider, obligationRepositoryProvider;
import '../features/dashboard/providers/member_dashboard_provider.dart'
    show paymentRepositoryProvider;
import '../features/dashboard/providers/treasurer_dashboard_provider.dart'
    show memberRepositoryProvider;
import '../features/expenses/providers/expense_provider.dart'
    show expenseRepositoryProvider;
import '../features/receipts/providers/receipt_provider.dart'
    show receiptRepositoryProvider;
import '../features/notifications/providers/notification_provider.dart';
import '../features/payments/providers/payment_provider.dart'
    show paymentServiceProvider;

bool kDemoMode = false;

class DemoAuthService implements AuthService {
  final Map<String, UserModel> _users = {};
  UserModel? _currentUser;

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_users.containsKey(email)) {
      throw Exception('Account not found. Please register first.');
    }
    _currentUser = _users[email];
    return _currentUser!;
  }

  @override
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required UserRole role,
    DateTime? dateOfBirth,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_users.containsKey(email)) {
      throw Exception('Email already registered.');
    }
    final user = UserModel(
      uid: email,
      email: email,
      displayName: displayName,
      phoneNumber: phoneNumber,
      role: role,
      createdAt: DateTime.now(),
    );
    _users[email] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoMemberRepository implements MemberRepository {
  final List<MemberModel> _members = [];

  @override
  Stream<List<MemberModel>> getMembers() =>
      Stream.value(List.unmodifiable(_members));

  @override
  Future<MemberModel?> getMemberByUserId(String userId) async =>
      _members.cast<MemberModel?>().firstWhere(
            (m) => m?.userId == userId,
            orElse: () => null,
          );

  @override
  Future<String> createMember(MemberModel member) async {
    _members.add(member);
    return member.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoPaymentRepository implements PaymentRepository {
  final List<PaymentModel> _payments = [];

  @override
  Stream<List<PaymentModel>> getMemberPayments(String memberId) =>
      Stream.value(_payments.where((p) => p.memberId == memberId).toList());

  @override
  Stream<List<PaymentModel>> getPendingPayments() =>
      Stream.value(_payments.where((p) => p.status == PaymentStatus.pending).toList());

  @override
  Stream<List<PaymentModel>> getAllPayments() =>
      Stream.value(List.unmodifiable(_payments));

  @override
  Future<PaymentModel?> getPaymentById(String id) async =>
      _payments.cast<PaymentModel?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          );

  @override
  Future<String> createPayment(PaymentModel payment) async {
    _payments.add(payment);
    return payment.id;
  }

  @override
  Future<void> updatePaymentStatus(
    String id, {
    required PaymentStatus status,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? receiptUrl,
  }) async {
    final idx = _payments.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _payments[idx] = _payments[idx].copyWith(
        status: status,
        verifiedBy: verifiedBy,
        verifiedAt: verifiedAt,
        receiptUrl: receiptUrl,
      );
    }
  }

  @override
  Future<void> updatePaymentAllocations(
    String id,
    List<PaymentAllocationModel> allocations,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoObligationRepository implements ObligationRepository {
  final List<ObligationModel> _obligations = [];

  @override
  Stream<List<ObligationModel>> getAllObligations() =>
      Stream.value(List.unmodifiable(_obligations));

  @override
  Stream<List<ObligationModel>> getMemberObligations(String memberId) =>
      Stream.value(_obligations.where((o) => o.memberId == memberId).toList());

  @override
  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) =>
      Stream.value(_obligations
          .where((o) =>
              o.memberId == memberId &&
              (o.status == ObligationStatus.unpaid ||
                  o.status == ObligationStatus.partial))
          .toList());

  @override
  Stream<List<ObligationModel>> getLevyObligations(String levyId) =>
      Stream.value(_obligations.where((o) => o.levyId == levyId).toList());

  Stream<List<ObligationModel>> getMemberObligationsByStatus(
    String memberId, {
    required ObligationStatus status,
  }) =>
      Stream.value(_obligations
          .where((o) => o.memberId == memberId && o.status == status)
          .toList());

  @override
  Future<ObligationModel?> getObligationById(String id) async =>
      _obligations.cast<ObligationModel?>().firstWhere(
            (o) => o?.id == id,
            orElse: () => null,
          );

  @override
  Future<String> createObligation(ObligationModel obligation) async {
    final id = 'demo-obl-${DateTime.now().millisecondsSinceEpoch}';
    final newObligation = obligation.copyWith(
      id: id,
      outstandingBalance: obligation.amount - obligation.paidAmount,
    );
    _obligations.add(newObligation);
    return id;
  }

  @override
  Future<void> updateObligationStatus(
    String id, {
    double? paidAmount,
    double? outstandingBalance,
    ObligationStatus? status,
    DateTime? settledAt,
  }) async {
    final idx = _obligations.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      _obligations[idx] = _obligations[idx].copyWith(
        paidAmount: paidAmount,
        outstandingBalance: outstandingBalance,
        status: status,
        settledAt: settledAt ?? _obligations[idx].settledAt,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoLevyRepository implements LevyRepository {
  final List<LevyModel> _levies = [];

  @override
  Stream<List<LevyModel>> getAllLevies() =>
      Stream.value(List.unmodifiable(_levies));

  @override
  Stream<List<LevyModel>> getActiveLevies() =>
      Stream.value(_levies.where((l) => l.isActive).toList());

  @override
  Future<LevyModel?> getLevyById(String id) async =>
      _levies.cast<LevyModel?>().firstWhere(
            (l) => l?.id == id,
            orElse: () => null,
          );

  @override
  Future<String> createLevy(LevyModel levy) async {
    _levies.add(levy);
    return levy.id;
  }

  @override
  Future<void> deactivateLevy(String id) async {
    final idx = _levies.indexWhere((l) => l.id == id);
    if (idx >= 0) {
      _levies[idx] = _levies[idx].copyWith(isActive: false);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoExpenseRepository implements ExpenseRepository {
  final List<ExpenseModel> _expenses = [];

  @override
  Stream<List<ExpenseModel>> getExpenses() =>
      Stream.value(List.unmodifiable(_expenses));

  @override
  Stream<List<ExpenseModel>> getExpensesByDateRange(DateTime start, DateTime end) =>
      Stream.value(_expenses
          .where((e) =>
              e.expenseDate.isAfter(start.subtract(const Duration(days: 1))) &&
              e.expenseDate.isBefore(end.add(const Duration(days: 1))))
          .toList());

  @override
  Future<ExpenseModel?> getExpenseById(String id) async =>
      _expenses.cast<ExpenseModel?>().firstWhere(
            (e) => e?.id == id,
            orElse: () => null,
          );

  @override
  Future<String> createExpense(ExpenseModel expense) async {
    _expenses.add(expense);
    return expense.id;
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx >= 0) _expenses[idx] = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoReceiptRepository implements ReceiptRepository {
  final List<ReceiptModel> _receipts = [];

  @override
  Stream<List<ReceiptModel>> getMemberReceipts(String memberId) =>
      Stream.value(_receipts.where((r) => r.memberId == memberId).toList());


  @override
  Stream<List<ReceiptModel>> getReceiptsByDateRange(DateTime start, DateTime end) =>
      Stream.value(_receipts
          .where((r) =>
              r.paymentDate.isAfter(start.subtract(const Duration(days: 1))) &&
              r.paymentDate.isBefore(end.add(const Duration(days: 1))))
          .toList());

  @override
  Future<ReceiptModel?> getReceiptById(String id) async =>
      _receipts.cast<ReceiptModel?>().firstWhere(
            (r) => r?.id == id,
            orElse: () => null,
          );

  @override
  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async =>
      _receipts.cast<ReceiptModel?>().firstWhere(
            (r) => r?.paymentId == paymentId,
            orElse: () => null,
          );

  @override
  Future<String> createReceipt(ReceiptModel receipt) async {
    _receipts.add(receipt);
    return receipt.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoNotificationService implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DemoPaymentService implements PaymentService {
  final List<String> _recordedPayments = [];

  @override
  Future<PaystackInitResult> initializePaystackPayment({
    required String email,
    required double amountNaira,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return PaystackInitResult(
      authorizationUrl: 'https://paystack.com/pay/demo',
      accessCode: 'demo_$reference',
      reference: reference,
    );
  }

  @override
  Future<PaystackVerifyResult> verifyPaystackTransaction({
    required String reference,
    required String memberId,
    required List<String> obligationIds,
    required double amountPaid,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final paymentId = 'pay_$reference';
    _recordedPayments.add(paymentId);
    return PaystackVerifyResult(
      paymentId: paymentId,
      receiptId: 'rec_$reference',
      receiptNumber: 'REC-$reference',
      verifiedAmount: amountPaid,
      status: 'success',
    );
  }

  @override
  Future<CashPaymentResult> recordCashPayment({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    String? notes,
    required String recordedBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final paymentId = 'cash_${DateTime.now().millisecondsSinceEpoch}';
    return CashPaymentResult(
      paymentId: paymentId,
      receiptId: 'rec_$paymentId',
      receiptNumber: 'REC-${paymentId.toUpperCase()}',
    );
  }

  @override
  Future<BankTransferResult> submitBankTransfer({
    required String memberId,
    required List<String> obligationIds,
    required double amount,
    required String transferReference,
    required String bankName,
    required String receiptUrl,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final paymentId = 'bt_${DateTime.now().millisecondsSinceEpoch}';
    return BankTransferResult(paymentId: paymentId);
  }

  @override
  Future<VerifyPaymentResult> verifyPayment({
    required String paymentId,
    required String action,
    required String verifiedBy,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return VerifyPaymentResult(
      success: action == 'approve',
      paymentId: paymentId,
      receiptId: 'rec_$paymentId',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> seedDemoData() async {
  final now = DateTime.now();
  final demoAuth = _demoAuthService;

  // Seed a member account
  final member = UserModel(
    uid: 'demo-member',
    email: 'member@demo.com',
    displayName: 'Demo Member',
    phoneNumber: '08011111111',
    role: UserRole.member,
    createdAt: now,
  );
  demoAuth._users['member@demo.com'] = member;

  // Seed a treasurer account
  final treasurer = UserModel(
    uid: 'demo-treasurer',
    email: 'treasurer@demo.com',
    displayName: 'Demo Treasurer',
    phoneNumber: '08022222222',
    role: UserRole.treasurer,
    createdAt: now,
  );
  demoAuth._users['treasurer@demo.com'] = treasurer;

  // Seed a president account
  final president = UserModel(
    uid: 'demo-president',
    email: 'president@demo.com',
    displayName: 'Demo President',
    phoneNumber: '08033333333',
    role: UserRole.president,
    createdAt: now,
  );
  demoAuth._users['president@demo.com'] = president;

  // Seed a member profile for the member account
  final memberProfile = MemberModel(
    id: 'demo-member-profile',
    userId: 'demo-member',
    fullName: 'Demo Member',
    email: 'member@demo.com',
    phoneNumber: '08011111111',
    dateOfBirth: DateTime(1990, 1, 1),
    joinedDate: DateTime(2020, 1, 1),
    createdAt: now,
    updatedAt: now,
  );
  _demoMemberRepo._members.add(memberProfile);

  // Seed a member profile for the treasurer account
  final treasurerProfile = MemberModel(
    id: 'demo-treasurer-profile',
    userId: 'demo-treasurer',
    fullName: 'Demo Treasurer',
    email: 'treasurer@demo.com',
    phoneNumber: '08022222222',
    dateOfBirth: DateTime(1985, 5, 15),
    joinedDate: DateTime(2018, 1, 1),
    createdAt: now,
    updatedAt: now,
  );
  _demoMemberRepo._members.add(treasurerProfile);

  // Seed a member profile for the president account
  final presidentProfile = MemberModel(
    id: 'demo-president-profile',
    userId: 'demo-president',
    fullName: 'Demo President',
    email: 'president@demo.com',
    phoneNumber: '08033333333',
    dateOfBirth: DateTime(1980, 8, 20),
    joinedDate: DateTime(2015, 1, 1),
    createdAt: now,
    updatedAt: now,
  );
  _demoMemberRepo._members.add(presidentProfile);

  // Seed a demo levy
  final levy = LevyModel(
    id: 'levy-1',
    title: 'Monthly Association Dues - June',
    description: 'Monthly contribution for June 2026',
    type: ObligationType.monthlyDue,
    amountPerMember: 5000,
    dueDate: now.add(const Duration(days: 15)),
    createdBy: 'demo-treasurer',
    createdAt: now,
    updatedAt: now,
  );
  _demoLevyRepo._levies.add(levy);

  // Seed obligations for the demo member
  final obligation1 = ObligationModel(
    id: 'obl-1',
    memberId: 'demo-member',
    levyId: 'levy-1',
    type: ObligationType.monthlyDue,
    title: 'Monthly Due - June',
    description: 'June 2026 monthly due',
    amount: 5000,
    paidAmount: 2000,
    outstandingBalance: 3000,
    status: ObligationStatus.partial,
    dueDate: now.add(const Duration(days: 15)),
    createdAt: now,
  );
  _demoObligationRepo._obligations.add(obligation1);

  final obligation2 = ObligationModel(
    id: 'obl-2',
    memberId: 'demo-member',
    levyId: '',
    type: ObligationType.specialLevy,
    title: 'Emergency Levy',
    description: 'Emergency community project levy',
    amount: 10000,
    paidAmount: 0,
    outstandingBalance: 10000,
    status: ObligationStatus.unpaid,
    dueDate: now.add(const Duration(days: 30)),
    createdAt: now,
  );
  _demoObligationRepo._obligations.add(obligation2);

  // Seed a payment
  final payment = PaymentModel(
    id: 'pay-1',
    memberId: 'demo-member',
    amount: 2000,
    method: PaymentMethod.cash,
    status: PaymentStatus.approved,
    allocations: const [],
    createdAt: now,
  );
  _demoPaymentRepo._payments.add(payment);

  // Seed an expense
  final expense = ExpenseModel(
    id: 'exp-1',
    title: 'Office Stationery',
    description: 'Printing paper and pens',
    amount: 3500,
    category: ExpenseCategory.administration,
    createdBy: 'demo-treasurer',
    expenseDate: now,
    createdAt: now,
    updatedAt: now,
  );
  _demoExpenseRepo._expenses.add(expense);

  // Seed a receipt
  final receipt = ReceiptModel(
    id: 'rec-1',
    receiptNumber: 'REC-001',
    paymentId: 'pay-1',
    memberId: 'demo-member',
    memberName: 'Demo Member',
    amount: 2000,
    method: PaymentMethod.cash,
    paymentDate: now,
    allocatedObligations: const [],
    createdAt: now,
  );
  _demoReceiptRepo._receipts.add(receipt);
}

final _demoAuthService = DemoAuthService();
final _demoMemberRepo = DemoMemberRepository();
final _demoPaymentRepo = DemoPaymentRepository();
final _demoObligationRepo = DemoObligationRepository();
final _demoLevyRepo = DemoLevyRepository();
final _demoExpenseRepo = DemoExpenseRepository();
final _demoReceiptRepo = DemoReceiptRepository();
final _demoNotificationService = DemoNotificationService();
final _demoPaymentService = DemoPaymentService();

/// Provider overrides to inject when running in demo mode.
List<Override> get demoOverrides => [
      authServiceProvider.overrideWithValue(_demoAuthService),
      memberRepositoryProvider.overrideWithValue(_demoMemberRepo),
      paymentRepositoryProvider.overrideWithValue(_demoPaymentRepo),
      obligationRepositoryProvider.overrideWithValue(_demoObligationRepo),
      levy_provider.levyRepositoryProvider
          .overrideWithValue(_demoLevyRepo),
      levy_provider.obligationRepositoryProvider
          .overrideWithValue(_demoObligationRepo),
      expenseRepositoryProvider.overrideWithValue(_demoExpenseRepo),
      receiptRepositoryProvider.overrideWithValue(_demoReceiptRepo),
      notificationServiceProvider.overrideWithValue(_demoNotificationService),
      paymentServiceProvider.overrideWithValue(_demoPaymentService),
    ];
