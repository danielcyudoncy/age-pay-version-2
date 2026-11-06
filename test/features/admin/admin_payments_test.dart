import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/admin/views/admin_payments_screen.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/payments/models/payment_model.dart';

void main() {
  final samplePayments = [
    PaymentModel(
      id: 'pay-1',
      memberId: 'm-1',
      memberName: 'John Doe',
      amount: 15000,
      method: PaymentMethod.bankTransfer,
      status: PaymentStatus.approved,
      allocations: const [],
      paystackReference: 'REF-1001',
      notes: 'Monthly dues payment',
      createdAt: DateTime(2026, 2, 10, 14, 30),
    ),
    PaymentModel(
      id: 'pay-2',
      memberId: 'm-2',
      memberName: 'Jane Smith',
      amount: 25000,
      method: PaymentMethod.online,
      status: PaymentStatus.pending,
      allocations: const [],
      paystackReference: 'REF-1002',
      notes: 'Development levy',
      createdAt: DateTime(2026, 2, 11, 10, 0),
    ),
    PaymentModel(
      id: 'pay-3',
      memberId: 'm-3',
      memberName: 'Bob Stone',
      amount: 5000,
      method: PaymentMethod.cash,
      status: PaymentStatus.rejected,
      allocations: const [],
      paystackReference: 'REF-1003',
      notes: 'Late submission rejected',
      createdAt: DateTime(2026, 2, 12, 16, 15),
    ),
  ];

  Widget buildTestableWidget({bool filterPendingOnly = false}) {
    return ProviderScope(
      overrides: [
        allPaymentsStreamProvider.overrideWith(
          (ref) => Stream.value(samplePayments),
        ),
      ],
      child: MaterialApp(
        home: AdminPaymentsScreen(filterPendingOnly: filterPendingOnly),
      ),
    );
  }

  testWidgets('AdminPaymentsScreen displays metrics, transactions, and search filters', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // 1. Verify title
    expect(find.text('Payment Ledger & Audits'), findsOneWidget);

    // 2. Verify KPI Cards
    // Total approved is 15,000 (shows in KPI card and in John Doe's card)
    expect(find.text('₦15,000'), findsNWidgets(2));
    expect(find.text('TOTAL COLLECTED'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);

    // 3. Verify Payment list items
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Bob Stone'), findsOneWidget);

    // 4. Test Search filter by member name
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Jane');
    await tester.pumpAndSettle();

    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('John Doe'), findsNothing);
    expect(find.text('Bob Stone'), findsNothing);

    // 5. Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Bob Stone'), findsOneWidget);

    // 6. Test Filter by Status: Pending
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('John Doe'), findsNothing);
    expect(find.text('Bob Stone'), findsNothing);

    // 7. Test Filter by Status: Rejected
    await tester.tap(find.text('Rejected'));
    await tester.pumpAndSettle();

    expect(find.text('Bob Stone'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);
    expect(find.text('John Doe'), findsNothing);
  });

  testWidgets('AdminPaymentsScreen initializes with Pending filter when requested', (tester) async {
    await tester.pumpWidget(buildTestableWidget(filterPendingOnly: true));
    await tester.pumpAndSettle();

    // Should only show Jane Smith (pending)
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('John Doe'), findsNothing);
    expect(find.text('Bob Stone'), findsNothing);
  });
}
