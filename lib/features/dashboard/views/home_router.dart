// features/dashboard/views/home_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../../core/constants/enums.dart';
import '../views/member_dashboard.dart';
import '../views/treasurer_dashboard.dart';
import '../views/president_dashboard.dart';
import 'package:cls/features/admin/views/admin_dashboard.dart';
import 'package:cls/features/meetings/views/secretary_dashboard.dart';
import '../../auth/views/login_screen.dart';

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
