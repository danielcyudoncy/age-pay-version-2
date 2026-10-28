// features/dashboard/views/home_router.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:cls/features/provost/views/provost_dashboard.dart';
import '../../auth/views/login_screen.dart';
import '../../auth/views/organization_picker_screen.dart';
import '../../auth/views/pending_approval_screen.dart';
import '../../auth/views/co_founder_verification_dialog.dart';
import '../../national/controllers/national_provider.dart';

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

        if (user.organizationId.isEmpty && user.role != UserRole.superAdmin) {
          return const OrganizationPickerScreen();
        }

        final activeScope = ref.watch(activeExecutiveScopeProvider);
        final effectiveRole =
            (activeScope == ExecutiveScope.national && user.nationalRole != null)
                ? user.nationalRole!
                : user.role;

        Widget dashboard;
        switch (effectiveRole) {
          case UserRole.member:
            dashboard = const MemberDashboard();
            break;
          case UserRole.treasurer:
          case UserRole.viceTreasurer:
            dashboard = const TreasurerDashboard();
            break;
          case UserRole.president:
          case UserRole.vicePresident:
            dashboard = const PresidentDashboard();
            break;
          case UserRole.secretary:
          case UserRole.viceSecretary:
            dashboard = const SecretaryDashboard();
            break;
          case UserRole.superAdmin:
            dashboard = const AdminDashboard();
            break;
          case UserRole.financialSecretary:
            dashboard = const FinancialSecretaryDashboard();
            break;
          case UserRole.publicRelationsOfficer:
            dashboard = const ProDashboard();
            break;
          case UserRole.provost:
            return const ProvostDashboard();
          case UserRole.auditor:
          case UserRole.executiveMember:
          case UserRole.committeeChair:
            dashboard = const MemberDashboard();
            break;
        }

        return _RootBackExitWrapper(child: dashboard);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Something went wrong'))),
    );
  }
}

class _RootBackExitWrapper extends StatefulWidget {
  final Widget child;
  const _RootBackExitWrapper({required this.child});

  @override
  State<_RootBackExitWrapper> createState() => _RootBackExitWrapperState();
}

class _RootBackExitWrapperState extends State<_RootBackExitWrapper> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
