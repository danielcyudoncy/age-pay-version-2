// features/settings/views/about_screen.dart
import 'package:flutter/material.dart';
import 'package:cls/core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _appVersion = '1.0.0';

  static const List<_AboutItem> _items = [
    _AboutItem(
      icon: Icons.groups_outlined,
      title: 'Members & contributions',
      body:
          'Manage members, track contributions, and keep records organized '
          'for your organization.',
    ),
    _AboutItem(
      icon: Icons.payments_outlined,
      title: 'Payments & expenses',
      body:
          'Record payments and expenses with a reliable, auditable financial '
          'trail.',
    ),
    _AboutItem(
      icon: Icons.event_available_outlined,
      title: 'Meetings & attendance',
      body:
          'Schedule meetings, capture minutes, and take attendance in one '
          'place.',
    ),
    _AboutItem(
      icon: Icons.lock_outline,
      title: 'Secure & multi-tenant',
      body:
          'Each organization works within its own isolated, secure '
          'workspace.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.brandGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  width: 220,
                  child: ClipRect(
                    child: OverflowBox(
                      maxHeight: 315,
                      maxWidth: 315,
                      alignment: const Alignment(-0.22, -0.11),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.account_balance_wallet,
                              size: 48,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Financial Management System',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Version $_appVersion',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._items.map((item) => _AboutCard(item: item)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '\u00a9 2026 AgePay. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final _AboutItem item;

  const _AboutCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(item.icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutItem {
  final IconData icon;
  final String title;
  final String body;

  const _AboutItem({
    required this.icon,
    required this.title,
    required this.body,
  });
}
