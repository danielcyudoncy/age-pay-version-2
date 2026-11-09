import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../admin/models/organization_model.dart';
import '../views/annual_license_screen.dart';

/// Reusable banner displayed across dashboards to communicate the software license lifecycle:
/// - 60-Day Welcome Trial
/// - 30-Day Renewal Notice (Executives only)
/// - 14-Day Grace Period
/// - Read-Only Mode (Grace Period expired)
/// - Payment Proof Under Verification
class LicenseStatusBanner extends StatelessWidget {
  final OrganizationModel org;
  final bool isExecutive;
  final EdgeInsetsGeometry? margin;

  const LicenseStatusBanner({
    super.key,
    required this.org,
    this.isExecutive = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine state
    if (org.isReadOnly) {
      return _buildCard(
        context: context,
        theme: theme,
        color: Colors.red,
        icon: Icons.lock_clock_outlined,
        title: isExecutive
            ? 'Annual License Expired — Read-Only Mode'
            : 'Organisation in Read-Only Mode',
        subtitle: isExecutive
            ? '14-day grace period has ended. New levies, collections, and broadcasts are paused until renewal. All past receipts, ledgers, and records remain fully accessible.'
            : 'Your community organisation\'s annual software license is awaiting renewal by executives. New payments and levies are paused. All your past receipts and ledgers remain 100% accessible.',
        actionLabel: isExecutive ? 'Renew License' : 'License Status',
        onAction: () => _openLicenseScreen(context),
      );
    }

    if (org.isInGracePeriod) {
      if (!isExecutive) return const SizedBox.shrink();
      final days = org.gracePeriodDaysRemaining;
      return _buildCard(
        context: context,
        theme: theme,
        color: Colors.amber,
        icon: Icons.timer_outlined,
        title: 'Software License Expired — 14-Day Grace Period',
        subtitle:
            '$days day(s) remaining in your grace period. Renew now to prevent interruption of new dues, levies, and meetings.',
        actionLabel: 'Renew Now',
        onAction: () => _openLicenseScreen(context),
      );
    }

    if (org.isLicensePendingVerification) {
      return _buildCard(
        context: context,
        theme: theme,
        color: Colors.blue,
        icon: Icons.hourglass_top_rounded,
        title: 'Renewal Proof Under Verification',
        subtitle:
            'A renewal bank transfer receipt was submitted and is under SuperAdmin review. All features remain fully operational.',
        actionLabel: 'View Status',
        onAction: () => _openLicenseScreen(context),
      );
    }

    if (org.isTrial) {
      final days = org.licenseDaysRemaining;
      if (org.isRenewalDueSoon) {
        return _buildCard(
          context: context,
          theme: theme,
          color: Colors.deepPurple,
          icon: Icons.alarm,
          title: '60-Day Trial Ending Soon',
          subtitle:
              '$days day(s) remaining of your 60-day complimentary trial. Review annual software license details to ensure continuous access.',
          actionLabel: 'Review License',
          onAction: () => _openLicenseScreen(context),
        );
      } else if (isExecutive) {
        return _buildCard(
          context: context,
          theme: theme,
          color: Colors.teal,
          icon: Icons.card_giftcard_rounded,
          title: '60-Day Welcome Trial Active',
          subtitle:
              '$days days remaining of your complimentary community onboarding trial. Enjoy full access across all modules.',
          actionLabel: 'View License',
          onAction: () => _openLicenseScreen(context),
        );
      }
    }

    if (org.isRenewalDueSoon && isExecutive) {
      final days = org.licenseDaysRemaining;
      final renewDate = org.subscriptionExpiresAt != null
          ? DateFormat('MMM dd, yyyy').format(org.subscriptionExpiresAt!)
          : 'soon';
      return _buildCard(
        context: context,
        theme: theme,
        color: Colors.indigo,
        icon: Icons.event_repeat_rounded,
        title: 'Annual License Renews Soon',
        subtitle:
            'Renews on $renewDate ($days day(s) remaining). Tap to review renewal fee and payment details.',
        actionLabel: 'Renewal Details',
        onAction: () => _openLicenseScreen(context),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCard({
    required BuildContext context,
    required ThemeData theme,
    required MaterialColor color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final statusColor = AppTheme.statusColor(context, color);
    final statusBg = AppTheme.statusBg(context, color);

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurface(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 32,
              child: FilledButton.tonal(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  foregroundColor: statusColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLicenseScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AnnualLicenseScreen(),
      ),
    );
  }
}
