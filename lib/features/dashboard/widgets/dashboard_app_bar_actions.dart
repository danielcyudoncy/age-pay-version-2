import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/views/login_screen.dart';
import '../../national/controllers/national_provider.dart';
import '../../national/views/national_hub_screen.dart';
import '../../notifications/controllers/notification_provider.dart';
import '../../notifications/views/notifications_screen.dart';
import '../../settings/views/about_screen.dart';
import '../../settings/views/help_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../admin/views/admin_profile_screen.dart';
import '../../secretary/views/secretary_profile_screen.dart';
import '../../members/views/member_profile_screen.dart';
import '../../calling/views/branch_directory_screen.dart';

/// Standardized executive AppBar actions across all AgePay dashboards.
/// Provides a consistent notifications badge, executive tier switcher, and a themed Material 3
/// overflow menu with Refresh, Settings, Help, About, and Sign Out.
class DashboardAppBarActions extends ConsumerWidget {
  final UserModel? user;
  final Future<void> Function()? onRefresh;
  final List<Widget>? extraActions;
  final bool showNotifications;
  final bool showScopeChip;
  final String refreshSuccessMessage;

  const DashboardAppBarActions({
    super.key,
    this.user,
    this.onRefresh,
    this.extraActions,
    this.showNotifications = true,
    this.showScopeChip = true,
    this.refreshSuccessMessage = 'Dashboard refreshed',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetUser = user ?? ref.watch(authProvider).valueOrNull;
    final activeScope = ref.watch(activeExecutiveScopeProvider);
    final hasNationalRole = targetUser?.nationalRole != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showScopeChip)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              backgroundColor: activeScope == ExecutiveScope.national
                  ? AppTheme.primaryContainer(context)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              avatar: Icon(
                activeScope == ExecutiveScope.national
                    ? Icons.stars_rounded
                    : Icons.location_on_outlined,
                size: 16,
                color: activeScope == ExecutiveScope.national
                    ? AppTheme.primary(context)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              label: Text(
                activeScope == ExecutiveScope.national ? 'National' : 'Branch',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: activeScope == ExecutiveScope.national
                      ? AppTheme.primary(context)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onPressed: () {
                final newScope = activeScope == ExecutiveScope.branch
                    ? ExecutiveScope.national
                    : ExecutiveScope.branch;
                ref.read(activeExecutiveScopeProvider.notifier).state = newScope;
                final branchLabel = (targetUser?.branchName != null &&
                        targetUser!.branchName!.trim().isNotEmpty)
                    ? targetUser.branchName!.trim()
                    : 'Local Branch';
                final nationalLabel = targetUser?.nationalRole != null
                    ? 'National View (${targetUser!.nationalRole!.displayName})'
                    : 'National Body View (Central Dues & Levies)';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(milliseconds: 1500),
                    backgroundColor: AppTheme.primary(context),
                    content: Text(
                      newScope == ExecutiveScope.national
                          ? 'Switched to $nationalLabel'
                          : 'Switched to Branch View ($branchLabel)',
                    ),
                  ),
                );
              },
            ),
          ),
        if (extraActions != null) ...extraActions!,
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.phone_in_talk_outlined,
            color: AppTheme.primary(context),
          ),
          tooltip: 'Branch Calls',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BranchDirectoryScreen(),
              ),
            );
          },
        ),
        if (showNotifications)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Badge(
              isLabelVisible: ref.watch(unreadCountProvider) > 0,
              label: Text('${ref.watch(unreadCountProvider)}'),
              child: Icon(
                Icons.notifications_outlined,
                color: AppTheme.primary(context),
              ),
            ),
            tooltip: 'Notifications',
            onPressed: () {
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
          icon: Icon(Icons.more_vert, color: AppTheme.primary(context)),
          tooltip: 'Menu',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) async {
            switch (value) {
              case 'branch_calls':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BranchDirectoryScreen(),
                  ),
                );
                break;
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
              case 'national_hub':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NationalHubScreen(initialTabIndex: 0),
                  ),
                );
                break;
              case 'leaderboard':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NationalHubScreen(initialTabIndex: 2),
                  ),
                );
                break;
              case 'switch_scope':
                final newScope = activeScope == ExecutiveScope.branch
                    ? ExecutiveScope.national
                    : ExecutiveScope.branch;
                ref.read(activeExecutiveScopeProvider.notifier).state = newScope;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1500),
                      backgroundColor: AppTheme.primary(context),
                      content: Text(
                        newScope == ExecutiveScope.national
                            ? 'Switched to National View (${targetUser?.nationalRole?.displayName})'
                            : 'Switched to Branch View (${targetUser?.branchName ?? 'Local'})',
                      ),
                    ),
                  );
                }
                break;
              case 'profile':
                Widget profileScreen;
                if (targetUser?.role == UserRole.superAdmin) {
                  profileScreen = const AdminProfileScreen();
                } else if (targetUser?.role == UserRole.secretary ||
                    targetUser?.role == UserRole.viceSecretary) {
                  profileScreen = const SecretaryProfileScreen();
                } else {
                  profileScreen = const MemberProfileScreen();
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => profileScreen),
                );
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
            if (hasNationalRole)
              PopupMenuItem<String>(
                value: 'switch_scope',
                child: Row(
                  children: [
                    Icon(
                      activeScope == ExecutiveScope.national
                          ? Icons.location_on_outlined
                          : Icons.stars_rounded,
                      size: 20,
                      color: AppTheme.primary(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      activeScope == ExecutiveScope.national
                          ? 'Switch to Branch View'
                          : 'Switch to National View',
                    ),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'national_hub',
              child: Row(
                children: [
                  Icon(Icons.public, size: 20, color: AppTheme.primary(context)),
                  SizedBox(width: 12),
                  Text('National Assembly & Ledger'),
                ],
              ),
            ),
            if (hasNationalRole ||
                targetUser?.role == UserRole.superAdmin ||
                targetUser?.role == UserRole.president ||
                targetUser?.role == UserRole.financialSecretary)
              PopupMenuItem<String>(
                value: 'leaderboard',
                child: Row(
                  children: [
                    Icon(Icons.leaderboard_outlined,
                        size: 20, color: AppTheme.primary(context)),
                    SizedBox(width: 12),
                    Text('Branch Leaderboard'),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'branch_calls',
              child: Row(
                children: [
                  Icon(Icons.phone_in_talk_outlined,
                      size: 20, color: AppTheme.primary(context)),
                  SizedBox(width: 12),
                  Text('Branch Calls'),
                ],
              ),
            ),
            if (onRefresh != null)
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: AppTheme.primary(context)),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 20, color: AppTheme.primary(context)),
                  SizedBox(width: 12),
                  Text('My Profile'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 20, color: AppTheme.primary(context)),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline,
                      size: 20, color: AppTheme.primary(context)),
                  SizedBox(width: 12),
                  Text('Help & Support'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'about',
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: AppTheme.primary(context)),
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

/// An expanded scope button designed for executive dashboard AppBars.
/// Fills the left/title area of the AppBar so it is not empty, showing the
/// current branch (or national) scope with a clean, touchable pill design.
class DashboardScopeTitle extends ConsumerWidget {
  final UserModel? user;

  const DashboardScopeTitle({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetUser = user ?? ref.watch(authProvider).valueOrNull;
    final activeScope = ref.watch(activeExecutiveScopeProvider);
    final theme = Theme.of(context);
    final isNational = activeScope == ExecutiveScope.national;
    final hasNationalRole = targetUser?.nationalRole != null;

    final userBranch = targetUser?.branchName?.trim();
    final branchName = (userBranch != null && userBranch.isNotEmpty)
        ? userBranch
        : null;

    final label = isNational
        ? 'National'
        : (branchName != null ? 'Branch • $branchName' : 'Branch');

    void onSwitch() {
      if (!hasNationalRole) return;
      final newScope = activeScope == ExecutiveScope.branch
          ? ExecutiveScope.national
          : ExecutiveScope.branch;
      ref.read(activeExecutiveScopeProvider.notifier).state = newScope;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          backgroundColor: AppTheme.primary(context),
          content: Text(
            newScope == ExecutiveScope.national
                ? 'Switched to National View (${targetUser?.nationalRole?.displayName})'
                : 'Switched to Branch View (${targetUser?.branchName ?? 'Local'})',
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (hasNationalRole) {
            onSwitch();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BranchDirectoryScreen(),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isNational
                ? AppTheme.primaryContainer(context)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNational
                  ? AppTheme.primary(context).withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                isNational ? Icons.stars_rounded : Icons.location_on_outlined,
                size: 18,
                color: isNational
                    ? AppTheme.primary(context)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isNational
                        ? AppTheme.primary(context)
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasNationalRole) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
