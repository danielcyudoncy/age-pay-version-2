import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/allocation_result.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/services/allocation_service.dart';

void main() {
  group('AllocationResult', () {
    final now = DateTime(2024, 6, 15);

    ObligationModel makeObligation({
      required String id,
      required double outstandingBalance,
      required DateTime dueDate,
      DateTime? createdAt,
    }) {
      return ObligationModel(
        id: id,
        memberId: 'member1',
        levyId: 'levy1',
        type: ObligationType.monthlyDue,
        title: 'Test Levy',
        description: 'Test description',
        amount: outstandingBalance,
        outstandingBalance: outstandingBalance,
        paidAmount: 0.0,
        status: ObligationStatus.unpaid,
        dueDate: dueDate,
        createdAt: createdAt ?? now,
      );
    }

    group('auto-allocate', () {
      test('exact amount to single obligation', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(5000, obligations);

        expect(result.allocations, {'obl1': 5000.0});
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 5000.0);
        expect(result.fullyPaidObligationIds, ['obl1']);
        expect(result.partiallyPaidObligationIds, isEmpty);
      });

      test('multiple obligations oldest-first', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 10),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 2000,
            dueDate: DateTime(2024, 1, 5),
          ),
          makeObligation(
            id: 'obl3',
            outstandingBalance: 4000,
            dueDate: DateTime(2024, 1, 15),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(8000, obligations);

        // obl2 due first (Jan 5), then obl1 (Jan 10), then obl3 (Jan 15)
        expect(result.allocations['obl2'], 2000.0);
        expect(result.allocations['obl1'], 3000.0);
        expect(result.allocations['obl3'], 3000.0);
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 8000.0);
        expect(
          result.fullyPaidObligationIds,
          unorderedEquals(<String>['obl1', 'obl2']),
        );
        expect(result.partiallyPaidObligationIds, ['obl3']);
      });

      test('partial payment (amount < first obligation outstanding)', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(2000, obligations);

        expect(result.allocations, {'obl1': 2000.0});
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 2000.0);
        expect(result.fullyPaidObligationIds, isEmpty);
        expect(result.partiallyPaidObligationIds, ['obl1']);
      });

      test('overpayment (amount > total outstanding) -> leftover', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 1),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 2000,
            dueDate: DateTime(2024, 1, 5),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(7000, obligations);

        expect(result.allocations['obl1'], 3000.0);
        expect(result.allocations['obl2'], 2000.0);
        expect(result.leftover, 2000.0);
        expect(result.totalAllocated, 5000.0);
        expect(
          result.fullyPaidObligationIds,
          unorderedEquals(<String>['obl1', 'obl2']),
        );
        expect(result.partiallyPaidObligationIds, isEmpty);
      });

      test('0 obligations -> full leftover', () {
        final result = AllocationResult.fromAutoAllocate(5000, []);

        expect(result.allocations, isEmpty);
        expect(result.leftover, 5000.0);
        expect(result.totalAllocated, 0.0);
        expect(result.fullyPaidObligationIds, isEmpty);
        expect(result.partiallyPaidObligationIds, isEmpty);
      });

      test('zero amount -> full leftover', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(0, obligations);

        expect(result.allocations, isEmpty);
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 0.0);
      });

      test('tie-breaker: createdAt when dueDate is equal', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 1000,
            dueDate: DateTime(2024, 1, 1),
            createdAt: DateTime(2024, 1, 2),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 1000,
            dueDate: DateTime(2024, 1, 1),
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(1500, obligations);

        // obl2 created first, so allocated first
        expect(result.allocations['obl2'], 1000.0);
        expect(result.allocations['obl1'], 500.0);
        expect(result.leftover, 0.0);
      });

      test('skips obligations with zero outstanding balance', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 0,
            dueDate: DateTime(2024, 1, 1),
          )..copyWith(status: ObligationStatus.paid),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 5),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(3000, obligations);

        expect(result.allocations.containsKey('obl1'), isFalse);
        expect(result.allocations['obl2'], 3000.0);
        expect(result.leftover, 0.0);
      });
    });

    group('manual allocate', () {
      test('exact selection', () {
        final selected = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromManualAllocate(5000, selected);

        expect(result.allocations, {'obl1': 5000.0});
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 5000.0);
        expect(result.fullyPaidObligationIds, ['obl1']);
        expect(result.partiallyPaidObligationIds, isEmpty);
      });

      test('insufficient selected outstanding - allows partial allocation', () {
        final selected = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromManualAllocate(5000, selected);

        expect(result.allocations, {'obl1': 3000.0});
        expect(result.leftover, 2000.0);
        expect(result.totalAllocated, 3000.0);
        expect(result.fullyPaidObligationIds, ['obl1']);
        expect(result.partiallyPaidObligationIds, isEmpty);
      });

      test('over-selection: caps at outstanding, does not allocate extra', () {
        final selected = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 1),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 5),
          ),
        ];

        final result = AllocationResult.fromManualAllocate(4000, selected);

        // First in selection order gets allocated fully, second gets remainder
        // The selection order is preserved, NOT sorted by dueDate
        expect(result.allocations['obl1'], 3000.0);
        expect(result.allocations['obl2'], 1000.0);
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 4000.0);
        expect(result.fullyPaidObligationIds, ['obl1']);
        expect(result.partiallyPaidObligationIds, ['obl2']);
      });

      test('empty selected list -> full leftover', () {
        final result = AllocationResult.fromManualAllocate(5000, []);

        expect(result.allocations, isEmpty);
        expect(result.leftover, 5000.0);
        expect(result.totalAllocated, 0.0);
      });

      test('zero amount -> full leftover', () {
        final selected = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromManualAllocate(0, selected);

        expect(result.allocations, isEmpty);
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 0.0);
      });
    });

    group('reallocate', () {
      test('reallocate payment to fewer obligations', () {
        final newObligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationService.reallocate(8000, newObligations, {
          'oldObl1': 3000,
          'oldObl2': 5000,
        });

        expect(result.allocations, {'obl1': 5000.0});
        expect(result.leftover, 3000.0);
        expect(result.totalAllocated, 5000.0);
        expect(result.total, 8000.0);
      });

      test('reallocate payment to more obligations', () {
        final newObligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 1),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 2000,
            dueDate: DateTime(2024, 1, 5),
          ),
          makeObligation(
            id: 'obl3',
            outstandingBalance: 4000,
            dueDate: DateTime(2024, 1, 10),
          ),
        ];

        final result = AllocationService.reallocate(7000, newObligations, {
          'oldObl1': 7000,
        });

        expect(result.allocations['obl1'], 3000.0);
        expect(result.allocations['obl2'], 2000.0);
        expect(result.allocations['obl3'], 2000.0);
        expect(result.leftover, 0.0);
        expect(result.totalAllocated, 7000.0);
        expect(result.total, 7000.0);
      });
    });

    group('edge cases', () {
      test('exact amount split across 3 obligations', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3333.33,
            dueDate: DateTime(2024, 1, 1),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 3333.33,
            dueDate: DateTime(2024, 1, 5),
          ),
          makeObligation(
            id: 'obl3',
            outstandingBalance: 3333.34,
            dueDate: DateTime(2024, 1, 10),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(10000.0, obligations);

        expect(result.totalAllocated, closeTo(10000.0, 0.01));
        expect(result.leftover, closeTo(0.0, 0.01));
        expect(result.allocations['obl1'], 3333.33);
        expect(result.allocations['obl2'], 3333.33);
        expect(result.allocations['obl3'], closeTo(3333.34, 0.01));
      });

      test('empty obligation list', () {
        final result = AllocationResult.fromAutoAllocate(5000, []);

        expect(result.allocations, isEmpty);
        expect(result.leftover, 5000.0);
        expect(result.totalAllocated, 0.0);
      });

      test('negative amount -> full leftover', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        final result = AllocationResult.fromAutoAllocate(-100, obligations);

        expect(result.allocations, isEmpty);
        expect(result.leftover, -100.0);
        expect(result.totalAllocated, 0.0);
      });
    });

    group('AllocationResult properties', () {
      test('total returns sum of allocated and leftover', () {
        final result = AllocationResult(
          allocations: {'obl1': 3000.0},
          leftover: 2000.0,
          totalAllocated: 3000.0,
          fullyPaidObligationIds: const ['obl1'],
          partiallyPaidObligationIds: const [],
        );

        expect(result.total, 5000.0);
      });

      test('empty factory sets full leftover', () {
        final result = AllocationResult.empty(7500.0);

        expect(result.allocations, isEmpty);
        expect(result.leftover, 7500.0);
        expect(result.totalAllocated, 0.0);
        expect(result.total, 7500.0);
      });

      test('copyWith updates fields', () {
        final result = AllocationResult.empty(5000.0);
        final copy = result.copyWith(
          allocations: {'obl1': 2000.0},
          totalAllocated: 2000.0,
          leftover: 3000.0,
        );

        expect(copy.allocations, {'obl1': 2000.0});
        expect(copy.totalAllocated, 2000.0);
        expect(copy.leftover, 3000.0);
        expect(copy.total, 5000.0);
      });

      test('equality and hashCode', () {
        final a = AllocationResult(
          allocations: {'obl1': 1000.0},
          leftover: 0.0,
          totalAllocated: 1000.0,
          fullyPaidObligationIds: const ['obl1'],
          partiallyPaidObligationIds: const [],
        );
        final b = AllocationResult(
          allocations: {'obl1': 1000.0},
          leftover: 0.0,
          totalAllocated: 1000.0,
          fullyPaidObligationIds: const ['obl1'],
          partiallyPaidObligationIds: const [],
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('AllocationService helpers', () {
      test('totalOutstanding sums balances', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 3000,
            dueDate: DateTime(2024, 1, 1),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 2000,
            dueDate: DateTime(2024, 1, 5),
          ),
        ];

        expect(AllocationService.totalOutstanding(obligations), 5000.0);
      });

      test('canCoverAmount returns true when sufficient', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 5000,
            dueDate: DateTime(2024, 1, 1),
          ),
        ];

        expect(AllocationService.canCoverAmount(3000, obligations), isTrue);
        expect(AllocationService.canCoverAmount(5000, obligations), isTrue);
        expect(AllocationService.canCoverAmount(6000, obligations), isFalse);
      });

      test('sortObligations sorts by dueDate then createdAt', () {
        final obligations = [
          makeObligation(
            id: 'obl1',
            outstandingBalance: 1000,
            dueDate: DateTime(2024, 1, 10),
            createdAt: DateTime(2024, 1, 2),
          ),
          makeObligation(
            id: 'obl2',
            outstandingBalance: 1000,
            dueDate: DateTime(2024, 1, 5),
            createdAt: DateTime(2024, 1, 1),
          ),
          makeObligation(
            id: 'obl3',
            outstandingBalance: 1000,
            dueDate: DateTime(2024, 1, 5),
            createdAt: DateTime(2024, 1, 3),
          ),
        ];

        final sorted = AllocationService.sortObligations(obligations);

        expect(sorted[0].id, 'obl2');
        expect(sorted[1].id, 'obl3');
        expect(sorted[2].id, 'obl1');
      });
    });
  });
}
