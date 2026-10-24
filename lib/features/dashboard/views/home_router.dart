// features/dashboard/views/home_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../../core/constants/enums.dart';
import '../views/member_dashboard.dart';
import '../views/treasurer_dashboard.dart';
import '../views/president_dashboard.dart';
import 'package:cls/features/admin/views/admin_dashboard.dart';
import 'package:cls/features/secretary/views/secretary_dashboard.dart';
import 'package:cls/features/financial_secretary/views/financial_secretary_dashboard.dart';
import 'package:cls/features/dashboard/views/pro_dashboard.dart';
import '../../auth/views/login_screen.dart';
import '../../auth/views/organization_picker_screen.dart';
import '../../auth/views/pending_approval_screen.dart';
import '../../auth/views/co_founder_verification_dialog.dart';

class HomeRouter extends ConsumerWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        // 1. Check if user has an incoming Co-Founder invitation for General Secretary
        if (user.phoneNumber.isNotEmpty) {
          final inviteAsync =
              ref.watch(userCoFounderInviteStreamProvider(user.phoneNumber));
          final invite = inviteAsync.valueOrNull;
          if (invite != null && invite.status == 'pending') {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: CoFounderVerificationDialog(
                      invitation: invite,
                      user: user,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        // 2. Gate unapproved users
        if (user.status == AccountStatus.pendingApproval ||
            user.status == AccountStatus.rejected) {
          return PendingApprovalScreen(user: user);
        }

        if (user.organizationId.isEmpty) {
          return const OrganizationPickerScreen();
        }

        switch (user.role) {
          case UserRole.member:
            return const MemberDashboard();
          case UserRole.treasurer:
          case UserRole.viceTreasurer:
            return const TreasurerDashboard();
          case UserRole.president:
          case UserRole.vicePresident:
            return const PresidentDashboard();
          case UserRole.secretary:
          case UserRole.viceSecretary:
            return const SecretaryDashboard();
          case UserRole.superAdmin:
            return const AdminDashboard();
          case UserRole.financialSecretary:
            return const FinancialSecretaryDashboard();
          case UserRole.publicRelationsOfficer:
            return const ProDashboard();
          case UserRole.auditor:
          case UserRole.executiveMember:
          case UserRole.committeeChair:
            return const MemberDashboard();
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Something went wrong'))),
    );
  }
}
