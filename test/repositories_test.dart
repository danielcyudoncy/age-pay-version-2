import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/members/repositories/member_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/payments/repositories/payment_repository.dart';
import 'package:cls/features/expenses/repositories/expense_repository.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/receipts/repositories/receipt_repository.dart';

class _MockFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Repository instantiation', () {
    final mockFirestore = _MockFirestore();

    test('MemberRepository can be instantiated with mock firestore', () {
      final repo = MemberRepository(firestore: mockFirestore);
      expect(repo, isNotNull);
    });

    test('ObligationRepository can be instantiated with mock firestore', () {
      final repo = ObligationRepository(firestore: mockFirestore);
      expect(repo, isNotNull);
    });

    test('PaymentRepository can be instantiated with mock firestore', () {
      final repo = PaymentRepository(firestore: mockFirestore);
      expect(repo, isNotNull);
    });

    test('ExpenseRepository can be instantiated with mock firestore', () {
      final repo = ExpenseRepository(firestore: mockFirestore);
      expect(repo, isNotNull);
    });

    test('LevyRepository can be instantiated with mock firestore', () {
      final repo = LevyRepository(firestore: mockFirestore);
      expect(repo, isNotNull);
    });

    test('ReceiptRepository can be instantiated with mock firestore', () {
      final repo = ReceiptRepository(firestore: mockFirestore);
      expect(repo, isNotNull);
    });
  });
}
