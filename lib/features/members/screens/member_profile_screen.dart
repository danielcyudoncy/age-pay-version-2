import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/features/auth/providers/auth_provider.dart';
import 'package:cls/features/dashboard/providers/treasurer_dashboard_provider.dart';
import 'edit_member_screen.dart';

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
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
                padding: const EdgeInsets.all(16),
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
            MaterialPageRoute(
              builder: (_) => EditMemberScreen(member: member),
            ),
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
            Text(
              member.email,
              style: TextStyle(color: Colors.grey.shade600),
            ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
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