import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/repositories/obligation_repository.dart';

final obligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository();
});

/// Stream of all obligations for treasurer / president view
final allObligationsProvider = StreamProvider.autoDispose<List<ObligationModel>>((ref) {
  final repo = ref.watch(obligationRepositoryProvider);
  return repo.getAllObligations();
});

/// Stream of a specific member's obligations
final memberObligationsProvider = StreamProvider.autoDispose.family<List<ObligationModel>, String>((ref, memberId) {
  final repo = ref.watch(obligationRepositoryProvider);
  return repo.getMemberObligations(memberId);
});

/// Stream of a specific member's active (unpaid/partial) obligations
final memberActiveObligationsProvider = StreamProvider.autoDispose.family<List<ObligationModel>, String>((ref, memberId) {
  final repo = ref.watch(obligationRepositoryProvider);
  return repo.getMemberActiveObligations(memberId);
});

/// Filter state for treasurer obligation management
class ObligationFilterState {
  final ObligationStatus? statusFilter;
  final String searchQuery;
  final String? memberIdFilter;

  const ObligationFilterState({
    this.statusFilter,
    this.searchQuery = '',
    this.memberIdFilter,
  });

  ObligationFilterState copyWith({
    ObligationStatus? statusFilter,
    String? searchQuery,
    String? memberIdFilter,
  }) {
    return ObligationFilterState(
      statusFilter: statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      memberIdFilter: memberIdFilter,
    );
  }
}

final obligationFilterProvider = StateProvider<ObligationFilterState>((ref) {
  return const ObligationFilterState();
});

/// Provider that exposes obligations filtered by the current filter state
final filteredObligationsProvider = Provider.autoDispose<AsyncValue<List<ObligationModel>>>((ref) {
  final obligationsAsync = ref.watch(allObligationsProvider);
  final filter = ref.watch(obligationFilterProvider);

  return obligationsAsync.when(
    data: (obligations) {
      var filtered = obligations;

      if (filter.statusFilter != null) {
        filtered = filtered.where((o) => o.status == filter.statusFilter).toList();
      }

      if (filter.memberIdFilter != null && filter.memberIdFilter!.isNotEmpty) {
        filtered = filtered.where((o) => o.memberId == filter.memberIdFilter).toList();
      }

      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        filtered = filtered.where((o) {
          return o.title.toLowerCase().contains(query) ||
              o.description.toLowerCase().contains(query);
        }).toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, st) => AsyncValue.error(err, st),
  );
});
