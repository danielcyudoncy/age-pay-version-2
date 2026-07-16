import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';

class SecretaryProfileScreen extends ConsumerWidget {
  const SecretaryProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: Text('Please sign in'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person, size: 48, color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: Text(user.displayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                const SizedBox(height: 4),
                Center(child: Text(user.email, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Secretary', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Phone'),
                    subtitle: Text(user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not provided'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Member Since'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(user.createdAt)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ),
    );
  }
}
