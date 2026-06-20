// features/dashboard/screens/home_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/enums.dart';
import '../screens/member_dashboard.dart';
import '../screens/treasurer_dashboard.dart';
import '../screens/president_dashboard.dart';
import '../screens/admin_dashboard.dart';
import '../../auth/screens/login_screen.dart';

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
