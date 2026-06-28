import '../models/allocation_result.dart';
import '../models/obligation_model.dart';

/// Pure service class for payment allocation logic.
/// No Firebase dependencies — just Dart logic.
class AllocationService {
  AllocationService._();

  /// Auto-allocate [amount] to [obligations], oldest due date first.
  /// Partial allocation is allowed.
  /// If amount > total outstanding, leftover is returned in the result.
  static AllocationResult autoAllocate(
    double amount,
    List<ObligationModel> obligations,
  ) {
    return AllocationResult.fromAutoAllocate(amount, obligations);
  }

  /// Validate that a manual selection of obligations can receive the payment.
  /// Returns the allocation map for selected obligations.
  static AllocationResult manualAllocate(
    double amount,
    List<ObligationModel> selectedObligations,
  ) {
    return AllocationResult.fromManualAllocate(amount, selectedObligations);
  }

  /// Re-allocate an existing payment across new obligations.
  /// Must ensure total allocated + leftover == paymentAmount.
  static AllocationResult reallocate(
    double paymentAmount,
    List<ObligationModel> newObligations,
    Map<String, double> currentAllocations,
  ) {
    // Re-allocation is auto-allocation against a fresh set of obligations,
    // ignoring the current allocations. The payment amount is fixed.
    return AllocationResult.fromAutoAllocate(paymentAmount, newObligations);
  }

  /// Sort obligations by dueDate ascending, then createdAt ascending.
  static List<ObligationModel> sortObligations(
    List<ObligationModel> obligations,
  ) {
    return List<ObligationModel>.from(obligations)..sort((a, b) {
      final dueCompare = a.dueDate.compareTo(b.dueDate);
      if (dueCompare != 0) return dueCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// Compute the total outstanding balance across a list of obligations.
  static double totalOutstanding(List<ObligationModel> obligations) {
    return obligations.fold(0.0, (sum, o) => sum + o.outstandingBalance);
  }

  /// Check whether a manual selection's total outstanding covers at least
  /// the requested amount. Returns true even if selected total > amount
  /// (partial selection within each obligation is handled during allocation).
  static bool canCoverAmount(
    double amount,
    List<ObligationModel> selectedObligations,
  ) {
    final total = totalOutstanding(selectedObligations);
    return total >= amount;
  }
}
