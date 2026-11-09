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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 450;

        void onSwitch() {
          final newScope = isNational
              ? ExecutiveScope.branch
              : ExecutiveScope.national;
          ref.read(activeExecutiveScopeProvider.notifier).state = newScope;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1500),
              backgroundColor: AppTheme.primary(context),
              content: Text(
                newScope == ExecutiveScope.national
                    ? 'Switched to National View ($nationalRoleTitle)'
                    : 'Switched to Branch View ($branchName - $branchRoleTitle)',
              ),
            ),
          );
        }

        final switchButton = FilledButton.tonalIcon(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: onSwitch,
        );

        final titleAndBadge = Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              isNational
                  ? 'Viewing: National Body'
                  : 'Viewing: $branchName',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isNational
                    ? AppTheme.primary(context)
                    : AppTheme.statusColor(context, Colors.amber),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: isNational
                    ? AppTheme.primaryContainer(context)
                    : AppTheme.statusBg(context, Colors.amber),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isNational ? nationalRoleTitle : branchRoleTitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isNational
                      ? AppTheme.primary(context)
                      : Colors.amber.shade900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        final subtitle = Text(
          isNational
              ? 'You also hold office as $branchRoleTitle in $branchName.'
              : 'You also hold office as $nationalRoleTitle in the National Body.',
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isNational
                ? AppTheme.primaryContainer(context)
                : AppTheme.statusBg(context, Colors.amber),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNational
                  ? AppTheme.primary(context).withValues(alpha: 0.35)
                  : AppTheme.statusColor(context, Colors.amber).withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isNational
                              ? AppTheme.primary(context)
                              : AppTheme.statusColor(context, Colors.amber),
                          child: Icon(
                            isNational
                                ? Icons.stars_rounded
                                : Icons.location_city,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleAndBadge,
                              const SizedBox(height: 2),
                              subtitle,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: switchButton,
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isNational
                          ? AppTheme.primary(context)
                          : Colors.amber.shade800,
                      child: Icon(
                        isNational
                            ? Icons.stars_rounded
                            : Icons.location_city,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleAndBadge,
                          const SizedBox(height: 2),
                          subtitle,
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    switchButton,
                  ],
                ),
        );
      },
    );
  }
}
