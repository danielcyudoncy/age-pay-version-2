// features/dashboard/widgets/dual_role_switcher_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../national/controllers/national_provider.dart';

/// A prominent, interactive banner that notifies dual-role executives
/// (users holding both a local branch office and a national body office)
/// of their active viewing tier and provides a 1-tap switcher between
/// their Branch and National dashboards.
class DualRoleSwitcherCard extends ConsumerWidget {
  final UserModel? user;

  const DualRoleSwitcherCard({
    super.key,
    this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = user ?? ref.watch(authProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    // Only render for users with dual offices (nationalRole assigned)
    if (currentUser.nationalRole == null) return const SizedBox.shrink();

    final activeScope = ref.watch(activeExecutiveScopeProvider);
    final theme = Theme.of(context);
    final isNational = activeScope == ExecutiveScope.national;

    final branchName = (currentUser.branchName != null &&
            currentUser.branchName!.trim().isNotEmpty)
        ? currentUser.branchName!.trim()
        : 'Local Branch';

    final nationalRoleTitle = currentUser.nationalRole!.displayName;
    final branchRoleTitle = currentUser.role.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isNational
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNational
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : Colors.amber.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isNational
                ? AppTheme.brandGreen
                : Colors.amber.shade800,
            child: Icon(
              isNational ? Icons.stars_rounded : Icons.location_city,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isNational
                            ? 'Viewing: National Body'
                            : 'Viewing: $branchName',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isNational
                              ? AppTheme.brandGreen
                              : Colors.amber.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isNational
                            ? AppTheme.brandGreen.withValues(alpha: 0.15)
                            : Colors.amber.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isNational ? nationalRoleTitle : branchRoleTitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isNational
                              ? AppTheme.brandGreen
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isNational
                      ? 'You also hold office as $branchRoleTitle in $branchName.'
                      : 'You also hold office as $nationalRoleTitle in the National Body.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: Icon(
              isNational ? Icons.location_on : Icons.stars_rounded,
              size: 16,
            ),
            label: Text(
              isNational ? 'Go to $branchName' : 'Go to National',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              final newScope = isNational
                  ? ExecutiveScope.branch
                  : ExecutiveScope.national;
              ref.read(activeExecutiveScopeProvider.notifier).state = newScope;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 1500),
                  backgroundColor: AppTheme.brandGreen,
                  content: Text(
                    newScope == ExecutiveScope.national
                        ? 'Switched to National View ($nationalRoleTitle)'
                        : 'Switched to Branch View ($branchName - $branchRoleTitle)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
