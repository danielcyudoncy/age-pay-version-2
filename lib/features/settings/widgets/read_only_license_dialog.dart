import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../views/annual_license_screen.dart';

/// Modal dialog shown when an executive attempts to perform a write action
/// (e.g. creating levies, recording payments, broadcasting announcements)
/// while their organization's annual license is hard-expired (past the 14-day grace period).
class ReadOnlyLicenseDialog extends StatelessWidget {
  final String actionName;

  const ReadOnlyLicenseDialog({
    super.key,
    required this.actionName,
  });

  static Future<bool?> show(
    BuildContext context, {
    String actionName = 'This action',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ReadOnlyLicenseDialog(actionName: actionName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.statusBg(context, Colors.red),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_clock_outlined,
              color: AppTheme.statusColor(context, Colors.red),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Read-Only Mode Active',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$actionName is temporarily paused because your organisation\'s annual software license has expired and the 14-day grace period has ended.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.onSurface(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_outlined,
                    color: AppTheme.primary(context),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All historical receipts, member ledgers, and past meeting records remain 100% safe and accessible.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context, true);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AnnualLicenseScreen(),
              ),
            );
          },
          icon: const Icon(Icons.credit_card, size: 16),
          label: const Text('Renew License'),
        ),
      ],
    );
  }
}
