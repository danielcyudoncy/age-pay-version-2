import '../../obligations/models/obligation_model.dart';

/// Result of allocating a payment across outstanding obligations.
class AllocationResult {
  final Map<String, double> allocations;
  final double leftover;
  final double totalAllocated;
  final List<String> fullyPaidObligationIds;
  final List<String> partiallyPaidObligationIds;

  const AllocationResult({
    required this.allocations,
    required this.leftover,
    required this.totalAllocated,
    required this.fullyPaidObligationIds,
    required this.partiallyPaidObligationIds,
  });

  /// Empty result with full amount as leftover.
  factory AllocationResult.empty(double amount) {
    return AllocationResult(
      allocations: const {},
      leftover: amount,
      totalAllocated: 0.0,
      fullyPaidObligationIds: const [],
      partiallyPaidObligationIds: const [],
    );
  }

  /// Auto-allocate [amount] to [obligations], oldest due date first.
  factory AllocationResult.fromAutoAllocate(
    double amount,
    List<ObligationModel> obligations,
  ) {
    if (amount <= 0 || obligations.isEmpty) {
      return AllocationResult.empty(amount);
    }

    final sorted = List<ObligationModel>.from(obligations)
      ..sort((a, b) {
        final dueCompare = a.dueDate.compareTo(b.dueDate);
        if (dueCompare != 0) return dueCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

    final allocations = <String, double>{};
    final fullyPaid = <String>[];
    final partiallyPaid = <String>[];
    double remaining = amount;
    double totalAllocated = 0.0;

    for (final obligation in sorted) {
      if (remaining <= 0) break;
      if (obligation.outstandingBalance <= 0) continue;

      final allocate = obligation.outstandingBalance < remaining
          ? obligation.outstandingBalance
          : remaining;

      allocations[obligation.id] = allocate;
      totalAllocated += allocate;
      remaining -= allocate;

      if (allocate >= obligation.outstandingBalance) {
        fullyPaid.add(obligation.id);
      } else {
        partiallyPaid.add(obligation.id);
      }
    }

    return AllocationResult(
      allocations: allocations,
      leftover: remaining,
      totalAllocated: totalAllocated,
      fullyPaidObligationIds: fullyPaid,
      partiallyPaidObligationIds: partiallyPaid,
    );
  }

  /// Validate and allocate [amount] to manually [selected] obligations.
  /// Capped at each obligation's outstanding balance.
  factory AllocationResult.fromManualAllocate(
    double amount,
    List<ObligationModel> selected,
  ) {
    if (amount <= 0 || selected.isEmpty) {
      return AllocationResult.empty(amount);
    }

    final allocations = <String, double>{};
    final fullyPaid = <String>[];
    final partiallyPaid = <String>[];
    double remaining = amount;
    double totalAllocated = 0.0;

    for (final obligation in selected) {
      if (remaining <= 0) break;
      if (obligation.outstandingBalance <= 0) continue;

      final allocate = obligation.outstandingBalance < remaining
          ? obligation.outstandingBalance
          : remaining;

      allocations[obligation.id] = allocate;
      totalAllocated += allocate;
      remaining -= allocate;

      if (allocate >= obligation.outstandingBalance) {
        fullyPaid.add(obligation.id);
      } else {
        partiallyPaid.add(obligation.id);
      }
    }

    return AllocationResult(
      allocations: allocations,
      leftover: remaining,
      totalAllocated: totalAllocated,
      fullyPaidObligationIds: fullyPaid,
      partiallyPaidObligationIds: partiallyPaid,
    );
  }

  /// Sum of all allocated amounts plus any leftover.
  double get total => totalAllocated + leftover;

  AllocationResult copyWith({
    Map<String, double>? allocations,
    double? leftover,
    double? totalAllocated,
    List<String>? fullyPaidObligationIds,
    List<String>? partiallyPaidObligationIds,
  }) {
    return AllocationResult(
      allocations: allocations ?? this.allocations,
      leftover: leftover ?? this.leftover,
      totalAllocated: totalAllocated ?? this.totalAllocated,
      fullyPaidObligationIds:
          fullyPaidObligationIds ?? this.fullyPaidObligationIds,
      partiallyPaidObligationIds:
          partiallyPaidObligationIds ?? this.partiallyPaidObligationIds,
    );
  }

  @override
  String toString() {
    return 'AllocationResult(allocations: $allocations, leftover: $leftover, '
        'totalAllocated: $totalAllocated, fullyPaid: $fullyPaidObligationIds, '
        'partiallyPaid: $partiallyPaidObligationIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllocationResult &&
        _mapEquals(other.allocations, allocations) &&
        other.leftover == leftover &&
        other.totalAllocated == totalAllocated &&
        _listEquals(other.fullyPaidObligationIds, fullyPaidObligationIds) &&
        _listEquals(
          other.partiallyPaidObligationIds,
          partiallyPaidObligationIds,
        );
  }

  @override
  int get hashCode => Object.hash(
    _mapHash(allocations),
    leftover,
    totalAllocated,
    Object.hashAll(fullyPaidObligationIds),
    Object.hashAll(partiallyPaidObligationIds),
  );
}

int _mapHash(Map<String, double> map) {
  var hash = 0;
  for (final entry
      in map.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    hash = Object.hash(hash, entry.key, entry.value);
  }
  return hash;
}

bool _mapEquals(Map<String, double> a, Map<String, double> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
