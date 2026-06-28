import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/data/repositories/obligation_repository.dart';
import 'package:cls/features/dashboard/providers/treasurer_dashboard_provider.dart'
    show membersStreamProvider;

final obligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository();
});

/// Stream of all obligations for treasurer / president view
final allObligationsProvider =
    StreamProvider.autoDispose<List<ObligationModel>>((ref) {
      final repo = ref.watch(obligationRepositoryProvider);
      return repo.getAllObligations();
    });

/// AsyncValue provider that filters obligations by member ID, handling both
/// document ID and user ID for compatibility with legacy data
final memberObligationsProvider = Provider.autoDispose
    .family<AsyncValue<List<ObligationModel>>, String>((ref, memberId) {
      final obligationsAsync = ref.watch(allObligationsProvider);
      final membersAsync = ref.watch(membersStreamProvider);

      return obligationsAsync.when(
        data: (obligations) {
          final members = membersAsync.valueOrNull ?? [];

          // Build a set of all possible IDs for this member (doc ID + user ID)
          final memberIds = <String>{memberId};
          for (final m in members) {
            if (m.userId == memberId) {
              memberIds.add(m.id);
            } else if (m.id == memberId) {
              memberIds.add(m.userId);
            }
          }

          return AsyncValue.data(
            obligations.where((o) => memberIds.contains(o.memberId)).toList(),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Provider for active (unpaid/partial) obligations of a specific member
final memberActiveObligationsProvider = Provider.autoDispose
    .family<AsyncValue<List<ObligationModel>>, String>((ref, memberId) {
      final allObligationsAsync = ref.watch(
        memberObligationsProvider(memberId),
      );

      return allObligationsAsync.when(
        data: (obligations) {
          return AsyncValue.data(
            obligations
                .where(
                  (o) =>
                      o.status == ObligationStatus.unpaid ||
                      o.status == ObligationStatus.partial,
                )
                .toList(),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
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
final filteredObligationsProvider =
    Provider.autoDispose<AsyncValue<List<ObligationModel>>>((ref) {
      final obligationsAsync = ref.watch(allObligationsProvider);
      final filter = ref.watch(obligationFilterProvider);

      return obligationsAsync.when(
        data: (obligations) {
          var filtered = obligations;

          if (filter.statusFilter != null) {
            filtered = filtered
                .where((o) => o.status == filter.statusFilter)
                .toList();
          }

          if (filter.memberIdFilter != null &&
              filter.memberIdFilter!.isNotEmpty) {
            filtered = filtered
                .where((o) => o.memberId == filter.memberIdFilter)
                .toList();
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
