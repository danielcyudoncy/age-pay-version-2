import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/national/controllers/national_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'edit_member_screen.dart';

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final activeScope = ref.watch(activeExecutiveScopeProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context, ref),
          ),
        ],
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please sign in'));
          }

          final memberAsync = ref.watch(memberByUserIdProvider(user.uid));

          return memberAsync.when(
            data: (member) {
              if (member == null) {
                return const Center(child: Text('Profile not found'));
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  _ProfileHeader(member: member, dateFormat: dateFormat),
                  const SizedBox(height: 24),
                  _ProfileSection(
                    title: 'Personal Information',
                    children: [
                      _ProfileInfoRow(
                        icon: Icons.person,
                        label: 'Full Name',
                        value: member.fullName,
                      ),
                      _ProfileInfoRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: member.email,
                      ),
                      _ProfileInfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: member.phoneNumber,
                      ),
                      _ProfileInfoRow(
                        icon: Icons.cake,
                        label: 'Date of Birth',
                        value: dateFormat.format(member.dateOfBirth),
                      ),
                      _ProfileInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Joined',
                        value: dateFormat.format(member.joinedDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ProfileSection(
                    title: 'Jurisdiction & Membership Tier',
                    children: [
                      _ProfileInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Local Branch',
                        value: (user.branchName != null &&
                                user.branchName!.trim().isNotEmpty)
                            ? user.branchName!.trim()
                            : 'Branch Member',
                      ),
                      const _ProfileInfoRow(
                        icon: Icons.stars_rounded,
                        label: 'National Body',
                        value: 'National Assembly (Enrolled)',
                      ),
                      if (user.nationalRole != null)
                        _ProfileInfoRow(
                          icon: Icons.military_tech_outlined,
                          label: 'National Executive Office',
                          value: user.nationalRole!.displayName,
                        ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.swap_horiz,
                              size: 18, color: AppTheme.primary(context)),
                          const SizedBox(width: 8),
                          Text(
                            'Active Account Context',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  ref
                                      .read(activeExecutiveScopeProvider.notifier)
                                      .state = ExecutiveScope.branch;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration:
                                          const Duration(milliseconds: 1500),
                                      backgroundColor: AppTheme.primary(context),
                                      content: Text(
                                        'Switched active view to ${user.branchName ?? 'Local Branch'}',
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: activeScope == ExecutiveScope.branch
                                        ? Theme.of(context).colorScheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: activeScope == ExecutiveScope.branch
                                        ? Border.all(
                                            color: AppTheme.primary(context)
                                                .withValues(alpha: 0.4),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 15,
                                        color: activeScope ==
                                                ExecutiveScope.branch
                                            ? AppTheme.primary(context)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          user.branchName ?? 'Branch',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: activeScope ==
                                                    ExecutiveScope.branch
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: activeScope ==
                                                    ExecutiveScope.branch
                                                ? AppTheme.primary(context)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  ref
                                      .read(activeExecutiveScopeProvider.notifier)
                                      .state = ExecutiveScope.national;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(milliseconds: 1500),
                                      backgroundColor: AppTheme.primary(context),
                                      content: Text(
                                        'Switched active view to National Body (Central Dues)',
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: activeScope == ExecutiveScope.national
                                        ? Theme.of(context).colorScheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: activeScope ==
                                            ExecutiveScope.national
                                        ? Border.all(
                                            color: const Color(0xFFB8860B)
                                                .withValues(alpha: 0.5),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        size: 15,
                                        color: activeScope ==
                                                ExecutiveScope.national
                                            ? const Color(0xFFB8860B)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'National Body',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: activeScope ==
                                                  ExecutiveScope.national
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: activeScope ==
                                                  ExecutiveScope.national
                                              ? const Color(0xFFB8860B)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Switching your active context filters your dashboard dues, receipts, and announcements to the selected tier.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ProfileSection(
                    title: 'Account',
                    children: [
                      _ProfileInfoRow(
                        icon: Icons.badge,
                        label: 'Role',
                        value: user.role.name.toUpperCase(),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Error loading profile: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    final memberAsync = ref.read(memberByUserIdProvider(user.uid));

    memberAsync.when(
      data: (member) {
        if (member != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditMemberScreen(member: member)),
          );
        }
      },
      loading: () {},
      error: (error, stackTrace) {},
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final MemberModel member;
  final DateFormat dateFormat;

  const _ProfileHeader({required this.member, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              child: Text(
                member.fullName.isNotEmpty ? member.fullName[0] : '?',
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              member.fullName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(member.email, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
