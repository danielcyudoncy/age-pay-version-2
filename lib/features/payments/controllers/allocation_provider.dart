import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/payments/models/allocation_result.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/obligations/services/allocation_service.dart';

/// State for allocation operations.
class AllocationState {
  final AllocationResult? result;
  final List<ObligationModel> selectedObligations;
  final bool isManual;
  final String? error;

  const AllocationState({
    this.result,
    this.selectedObligations = const [],
    this.isManual = false,
    this.error,
  });

  AllocationState copyWith({
    AllocationResult? result,
    List<ObligationModel>? selectedObligations,
    bool? isManual,
    String? error,
    bool clearError = false,
  }) {
    return AllocationState(
      result: result ?? this.result,
      selectedObligations: selectedObligations ?? this.selectedObligations,
      isManual: isManual ?? this.isManual,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for managing allocation state.
class AllocationNotifier extends StateNotifier<AllocationState> {
  AllocationNotifier() : super(const AllocationState());

  /// Auto-allocate [amount] across all outstanding [obligations].
  /// Pre-selects the obligations that will receive allocation.
  void autoAllocate(double amount, List<ObligationModel> obligations) {
    final result = AllocationService.autoAllocate(amount, obligations);
    final allocatedIds = result.allocations.keys.toSet();
    final selected = obligations
        .where((o) => allocatedIds.contains(o.id))
        .toList();

    state = state.copyWith(
      result: result,
      selectedObligations: selected,
      isManual: false,
      clearError: true,
    );
  }

  /// Add an obligation to the manual selection.
  void selectObligation(ObligationModel obligation) {
    if (state.selectedObligations.any((o) => o.id == obligation.id)) return;
    final updated = [...state.selectedObligations, obligation];
    state = state.copyWith(
      selectedObligations: updated,
      isManual: true,
      clearError: true,
    );
  }

  /// Remove an obligation from the manual selection.
  void deselectObligation(ObligationModel obligation) {
    final updated = state.selectedObligations
        .where((o) => o.id != obligation.id)
        .toList();
    state = state.copyWith(
      selectedObligations: updated,
      isManual: true,
      clearError: true,
    );
  }

  /// Manual allocate [amount] across currently selected obligations.
  void manualAllocate(double amount) {
    if (state.selectedObligations.isEmpty) {
      state = state.copyWith(
        result: AllocationResult.empty(amount),
        error: 'No obligations selected',
      );
      return;
    }

    final result = AllocationService.manualAllocate(
      amount,
      state.selectedObligations,
    );
    state = state.copyWith(result: result, isManual: true, clearError: true);
  }

  /// Re-allocate an existing payment across a new set of obligations.
  void reallocate(double paymentAmount, List<ObligationModel> obligations) {
    final result = AllocationService.reallocate(
      paymentAmount,
      obligations,
      state.result?.allocations ?? {},
    );
    final allocatedIds = result.allocations.keys.toSet();
    final selected = obligations
        .where((o) => allocatedIds.contains(o.id))
        .toList();

    state = state.copyWith(
      result: result,
      selectedObligations: selected,
      isManual: false,
      clearError: true,
    );
  }

  /// Clear all allocation state.
  void clear() {
    state = const AllocationState();
  }

  /// Toggle an obligation in the selection.
  void toggleObligation(ObligationModel obligation) {
    final isSelected = state.selectedObligations.any(
      (o) => o.id == obligation.id,
    );
    if (isSelected) {
      deselectObligation(obligation);
    } else {
      selectObligation(obligation);
    }
  }

  /// Compute a preview for the current selection without committing state.
  AllocationResult previewManualAllocate(double amount) {
    if (state.selectedObligations.isEmpty) {
      return AllocationResult.empty(amount);
    }
    return AllocationService.manualAllocate(amount, state.selectedObligations);
  }
}

final allocationProvider =
    StateNotifierProvider<AllocationNotifier, AllocationState>((ref) {
      return AllocationNotifier();
    });
