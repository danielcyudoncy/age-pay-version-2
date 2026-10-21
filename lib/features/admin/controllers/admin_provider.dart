import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organization_model.dart';
import '../repositories/organization_repository.dart';
import '../models/branch_model.dart';
import '../repositories/branch_repository.dart';
import '../models/admin_dashboard_data.dart';
import '../../auth/controllers/auth_provider.dart';

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository();
});

final branchesStreamFamily =
    StreamProvider.family<List<BranchModel>, String>((ref, organizationId) {
  return ref.watch(branchRepositoryProvider).getBranches(organizationId);
});

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

final organizationsStreamProvider = StreamProvider<List<OrganizationModel>>((ref) {
  return ref.watch(organizationRepositoryProvider).getOrganizations();
});

final organizationsFutureProvider =
    FutureProvider<List<OrganizationModel>>((ref) {
      return ref
          .watch(organizationRepositoryProvider)
          .getPublicOrganizations()
          .first;
    });

final totalOrganizationsProvider = Provider<AsyncValue<int>>((ref) {
  final asyncOrgs = ref.watch(organizationsStreamProvider);
  return asyncOrgs.whenData((list) => list.length);
});

final activeOrganizationsProvider = Provider<AsyncValue<int>>((ref) {
  final asyncOrgs = ref.watch(organizationsStreamProvider);
  return asyncOrgs.whenData((list) => list.where((o) => o.isActive).length);
});

final adminDashboardProvider = Provider<AsyncValue<AdminDashboardData>>((ref) {
  final totalOrgsAsync = ref.watch(totalOrganizationsProvider);
  final activeOrgsAsync = ref.watch(activeOrganizationsProvider);

  return totalOrgsAsync.whenData((total) {
    final active = activeOrgsAsync.valueOrNull ?? 0;
    return AdminDashboardData(
      totalOrganizations: total,
      totalUsers: 0,
      activeOrganizations: active,
      pendingApprovals: 0,
      recentOrganizations: const [],
    );
  });
});

final currentOrganizationProvider =
    FutureProvider.autoDispose<OrganizationModel?>((ref) async {
      final orgId = await ref.watch(organizationIdProvider.future);
      if (orgId.isEmpty) return null;
      return ref
          .watch(organizationRepositoryProvider)
          .getOrganizationById(orgId);
    });
