import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../admin/controllers/admin_provider.dart';
import '../../admin/widgets/edit_organization_bank_dialog.dart';
import '../../../core/constants/enums.dart';
import '../controllers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.watch(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          _SectionHeader(title: 'Organization Account', icon: Icons.account_balance_outlined),
          const _OrganizationBankCard(),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.dark_mode_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Theme'),
                    subtitle: Text(_themeLabel(settings.themeMode)),
                    trailing: DropdownButton<ThemeMode>(
                      value: settings.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) notifier.setThemeMode(mode);
                      },
                    ),
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.view_compact_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Compact view'),
                    subtitle: const Text('Show denser lists and cards'),
                    value: settings.compactView,
                    onChanged: notifier.setCompactView,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Notifications', icon: Icons.notifications_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.notifications_active_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Push notifications'),
                    subtitle: const Text('Receive app notifications'),
                    value: settings.notificationsEnabled,
                    onChanged: notifier.setNotificationsEnabled,
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.payments_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Contribution reminders'),
                    subtitle: const Text('Remind members about dues'),
                    value: settings.contributionReminders,
                    onChanged: settings.notificationsEnabled
                        ? notifier.setContributionReminders
                        : null,
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.event_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Meeting reminders'),
                    subtitle: const Text('Alert before scheduled meetings'),
                    value: settings.meetingReminders,
                    onChanged: settings.notificationsEnabled
                        ? notifier.setMeetingReminders
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Security', icon: Icons.security_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.fingerprint,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Biometric lock'),
                    subtitle: const Text('Require fingerprint or face to open'),
                    value: settings.biometricLock,
                    onChanged: notifier.setBiometricLock,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settings are stored on this device and apply across '
                      'your AgePay workspace.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationBankCard extends ConsumerWidget {
  const _OrganizationBankCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final user = ref.watch(authProvider).valueOrNull;

    final canEdit = user != null &&
        (user.role == UserRole.treasurer ||
            user.role == UserRole.viceTreasurer ||
            user.role == UserRole.president ||
            user.role == UserRole.vicePresident ||
            user.role == UserRole.superAdmin ||
            user.role == UserRole.financialSecretary ||
            user.role == UserRole.secretary);

    return orgAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (org) {
        if (org == null) return const SizedBox.shrink();

        final bankName = (org.bankName?.isNotEmpty == true)
            ? org.bankName!
            : 'First Bank of Nigeria';
        final accountNumber = (org.accountNumber?.isNotEmpty == true)
            ? org.accountNumber!
            : 'Not configured';
        final accountName = (org.accountName?.isNotEmpty == true)
            ? org.accountName!
            : org.name;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Receiving Bank',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Members pay levies to this account',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      IconButton.filledTonal(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Bank Details',
                        onPressed: () {
                          EditOrganizationBankDialog.show(
                            context,
                            organization: org,
                          );
                        },
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BANK NAME',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bankName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (accountNumber != 'Not configured')
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: accountNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Account number copied: $accountNumber'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT NUMBER',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountNumber,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT NAME',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (canEdit) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        EditOrganizationBankDialog.show(
                          context,
                          organization: org,
                        );
                      },
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Edit Bank Account Details'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

