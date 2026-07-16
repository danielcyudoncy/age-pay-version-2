import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
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
