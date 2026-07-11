import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organization_model.dart';
import '../repositories/organization_repository.dart';
import '../models/admin_dashboard_data.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

final organizationsStreamProvider = StreamProvider<List<OrganizationModel>>((ref) {
  return ref.watch(organizationRepositoryProvider).getOrganizations();
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
