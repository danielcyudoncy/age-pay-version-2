import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/views/login_screen.dart';
import '../../notifications/controllers/notification_provider.dart';
import '../../notifications/views/notifications_screen.dart';
import '../../settings/views/about_screen.dart';
import '../../settings/views/help_screen.dart';
import '../../settings/views/settings_screen.dart';

/// Standardized executive AppBar actions across all AgePay dashboards.
/// Provides a consistent notifications badge and a themed Material 3
/// overflow menu with Refresh, Settings, Help, About, and Sign Out.
class DashboardAppBarActions extends ConsumerWidget {
  final UserModel? user;
  final Future<void> Function()? onRefresh;
  final List<Widget>? extraActions;
  final bool showNotifications;
  final String refreshSuccessMessage;

  const DashboardAppBarActions({
    super.key,
    this.user,
    this.onRefresh,
    this.extraActions,
    this.showNotifications = true,
    this.refreshSuccessMessage = 'Dashboard refreshed',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (extraActions != null) ...extraActions!,
        if (showNotifications)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Badge(
              isLabelVisible: ref.watch(unreadCountProvider) > 0,
              label: Text('${ref.watch(unreadCountProvider)}'),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.brandGreen,
              ),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              final targetUser = user ?? ref.read(authProvider).valueOrNull;
              if (targetUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(currentUser: targetUser),
                  ),
                );
              }
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.brandGreen),
          tooltip: 'Menu',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) async {
            switch (value) {
              case 'refresh':
                if (onRefresh != null) {
                  await onRefresh!();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(refreshSuccessMessage),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                }
                break;
              case 'settings':
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                break;
              case 'help':
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
                break;
              case 'about':
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
                break;
              case 'logout':
                final navigator = Navigator.of(context);
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                if (shouldLogout == true && context.mounted) {
                  await ref.read(authProvider.notifier).signOut();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
                break;
            }
          },
          itemBuilder: (context) => [
            if (onRefresh != null)
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: AppTheme.brandGreen),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 20, color: AppTheme.brandGreen),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline,
                      size: 20, color: AppTheme.brandGreen),
                  SizedBox(width: 12),
                  Text('Help & Support'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'about',
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: AppTheme.brandGreen),
                  SizedBox(width: 12),
                  Text('About AgePay'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
