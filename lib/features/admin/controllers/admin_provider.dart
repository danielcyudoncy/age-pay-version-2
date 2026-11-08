import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organization_model.dart';
import '../services/system_reset_service.dart';
import '../repositories/organization_repository.dart';
import '../models/branch_model.dart';
import '../repositories/branch_repository.dart';
import '../models/admin_dashboard_data.dart';
import '../models/system_settings_model.dart';
import '../repositories/admin_user_repository.dart';
import '../repositories/system_settings_repository.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../core/constants/enums.dart';
import '../../dashboard/controllers/treasurer_dashboard_provider.dart'
    show allPaymentsStreamProvider;

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository();
});

final branchesStreamFamily =
    StreamProvider.autoDispose.family<List<BranchModel>, String>((
  ref,
  organizationId,
) {
  return ref.watch(branchRepositoryProvider).getBranches(organizationId);
});

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

final organizationsStreamProvider =
    StreamProvider.autoDispose<List<OrganizationModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) {
    return const Stream.empty();
  }
  return ref.watch(organizationRepositoryProvider).getOrganizations();
});

final organizationsFutureProvider =
    StreamProvider.autoDispose<List<OrganizationModel>>((ref) {
  return ref.watch(organizationRepositoryProvider).getPublicOrganizations();
});

/// Alias for [organizationsFutureProvider] with idiomatic StreamProvider naming.
final publicOrganizationsStreamProvider = organizationsFutureProvider;

final totalOrganizationsProvider =
    Provider.autoDispose<AsyncValue<int>>((ref) {
  final asyncOrgs = ref.watch(organizationsStreamProvider);
  return asyncOrgs.whenData((list) => list.length);
});

final activeOrganizationsProvider =
    Provider.autoDispose<AsyncValue<int>>((ref) {
  final asyncOrgs = ref.watch(organizationsStreamProvider);
  return asyncOrgs.whenData((list) => list.where((o) => o.isActive).length);
});

final adminUserRepositoryProvider = Provider<AdminUserRepository>((ref) {
  return AdminUserRepository();
});

final allUsersStreamProvider =
    StreamProvider.autoDispose<List<UserModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) {
    return const Stream.empty();
  }
  return ref.watch(adminUserRepositoryProvider).getUsersStream();
});

final systemSettingsRepositoryProvider =
    Provider<SystemSettingsRepository>((ref) {
  return SystemSettingsRepository();
});

final systemSettingsStreamProvider =
    StreamProvider.autoDispose<SystemSettingsModel>((ref) {
  return ref.watch(systemSettingsRepositoryProvider).streamSettings();
});

final adminDashboardProvider =
    Provider.autoDispose<AsyncValue<AdminDashboardData>>((ref) {
  final totalOrgsAsync = ref.watch(totalOrganizationsProvider);
  final activeOrgsAsync = ref.watch(activeOrganizationsProvider);
  final allUsersAsync = ref.watch(allUsersStreamProvider);
  final allPaymentsAsync = ref.watch(allPaymentsStreamProvider);

  return totalOrgsAsync.whenData((total) {
    final active = activeOrgsAsync.valueOrNull ?? 0;
    final users = allUsersAsync.valueOrNull ?? [];
    final payments = allPaymentsAsync.valueOrNull ?? [];

    final approvedPayments = payments.where((p) => p.status == PaymentStatus.approved);
    final totalCollections = approvedPayments.fold<double>(
      0.0,
      (sum, p) => sum + p.amount,
    );

    final pending = users
        .where(
          (u) =>
              u.status == AccountStatus.pendingApproval || !u.isActive,
        )
        .length;

    return AdminDashboardData(
      totalOrganizations: total,
      totalUsers: users.length,
      activeOrganizations: active,
      pendingApprovals: pending,
      totalCollections: totalCollections,
      totalPaymentsCount: payments.length,
      recentOrganizations: const [],
    );
  });
});

final currentOrganizationProvider =
    StreamProvider.autoDispose<OrganizationModel?>((ref) async* {
      final orgId = await ref.watch(organizationIdProvider.future);
      final orgRepo = ref.watch(organizationRepositoryProvider);

      if (orgId.isNotEmpty) {
        final direct = await orgRepo.getOrganizationById(orgId);
        if (direct != null &&
            direct.accountNumber != null &&
            direct.accountNumber!.trim().isNotEmpty) {
          yield* orgRepo.streamOrganizationById(orgId);
          return;
        }
      }

      // If current org has no bank account configured, find the configured one
      try {
        final allOrgs = await orgRepo.getOrganizations().first;
        final configured = allOrgs
            .where(
              (o) =>
                  o.accountNumber != null && o.accountNumber!.trim().isNotEmpty,
            )
            .firstOrNull;

        if (configured != null) {
          yield* orgRepo.streamOrganizationById(configured.id);
          return;
        }

        if (orgId.isNotEmpty) {
          final direct = await orgRepo.getOrganizationById(orgId);
          if (direct != null) {
            yield* orgRepo.streamOrganizationById(orgId);
            return;
          }
        }
      } catch (_) {}

      final fallbackOrgId = await ref
          .watch(authServiceProvider)
          .getActiveOrganizationId();
      if (fallbackOrgId.isNotEmpty) {
        yield* orgRepo.streamOrganizationById(fallbackOrgId);
      } else {
        yield null;
      }
    });

final systemResetServiceProvider = Provider<SystemResetService>((ref) {
  return SystemResetService();
});

