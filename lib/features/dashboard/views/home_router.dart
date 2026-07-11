// features/dashboard/views/home_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../../core/constants/enums.dart';
import '../views/member_dashboard.dart';
import '../views/treasurer_dashboard.dart';
import '../views/president_dashboard.dart';
import '../views/admin_dashboard.dart';
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
            return const TreasurerDashboard();
          case UserRole.president:
            return const PresidentDashboard();
          case UserRole.superAdmin:
            return const AdminDashboard();
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Something went wrong'))),
    );
  }
}
