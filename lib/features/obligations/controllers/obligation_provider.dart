import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show membersStreamProvider;
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/national/controllers/national_provider.dart';

final obligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository();
});

/// Stream of all obligations for treasurer / president view, scoped to active branch
final allObligationsProvider =
    StreamProvider.autoDispose<List<ObligationModel>>((ref) {
      final user = ref.watch(authProvider).valueOrNull;
      if (user == null) return const Stream.empty();

      final activeScope = ref.watch(activeExecutiveScopeProvider);
      final isNationalScope = activeScope == ExecutiveScope.national;

      final repo = ref.watch(obligationRepositoryProvider);
      final obligationsStream = repo.getAllObligations();

      if (isNationalScope) {
        // In national scope, stream national-scoped obligations
        return obligationsStream.map((obligations) {
          return obligations
              .where((o) => o.scope.trim().toLowerCase() == 'national')
              .toList();
        });
      }

      if (user.role == UserRole.superAdmin ||
          user.branchId == null ||
          user.branchId!.isEmpty) {
        return obligationsStream.map((obligations) {
          return obligations
              .where((o) => o.scope.trim().toLowerCase() != 'national')
              .toList();
        });
      }

      final membersAsync = ref.watch(membersStreamProvider);
      final members = membersAsync.valueOrNull ?? [];
      final branchMemberIds = <String>{};
      for (final m in members) {
        if (m.branchId == user.branchId) {
          branchMemberIds.add(m.id);
          if (m.userId.isNotEmpty) branchMemberIds.add(m.userId);
        }
      }
      branchMemberIds.add(user.uid);

      return obligationsStream.map((obligations) {
        return obligations.where((o) {
          if (o.scope.trim().toLowerCase() == 'national') return false;
          if (o.branchId != null && o.branchId!.isNotEmpty) {
            return o.branchId == user.branchId;
          }
          return branchMemberIds.contains(o.memberId);
        }).toList();
      });
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

          final matching = obligations
              .where((o) => memberIds.contains(o.memberId))
              .toList();

          // Deduplicate by levyId or title to prevent duplicate charges for the same levy
          final deduplicated = <String, ObligationModel>{};
          for (final o in matching) {
            final key = o.levyId.isNotEmpty
                ? 'levy_${o.levyId}'
                : 'title_${o.type.name}_${o.title.trim().toLowerCase()}';
            if (!deduplicated.containsKey(key)) {
              deduplicated[key] = o;
            } else {
              final existing = deduplicated[key]!;
              if (o.paidAmount > existing.paidAmount) {
                deduplicated[key] = o;
              }
            }
          }

          return AsyncValue.data(deduplicated.values.toList());
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
      final membersAsync = ref.watch(membersStreamProvider);

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
            final members = membersAsync.valueOrNull ?? [];
            final memberMap = <String, String>{};
            for (final m in members) {
              memberMap[m.id] = m.fullName.toLowerCase();
              if (m.userId.isNotEmpty) {
                memberMap[m.userId] = m.fullName.toLowerCase();
              }
            }

            filtered = filtered.where((o) {
              final memberName = memberMap[o.memberId] ?? '';
              return o.title.toLowerCase().contains(query) ||
                  o.description.toLowerCase().contains(query) ||
                  memberName.contains(query);
            }).toList();
          }

          return AsyncValue.data(filtered);
        },
        loading: () => const AsyncValue.loading(),
        error: (err, st) => AsyncValue.error(err, st),
      );
    });

/// Auto-cleans up duplicate unpaid obligations across the entire organization
final organizationObligationsCleanupProvider =
    FutureProvider.autoDispose.family<int, String>((ref, organizationId) async {
      if (organizationId.isEmpty) return 0;
      final repo = ref.watch(obligationRepositoryProvider);
      return repo.cleanupOrganizationDuplicateObligations(organizationId);
    });
