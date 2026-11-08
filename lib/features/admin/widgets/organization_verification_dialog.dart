import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/organization_model.dart';
import '../controllers/admin_provider.dart';
import 'edit_organization_bank_dialog.dart';

class OrganizationVerificationDialog extends ConsumerStatefulWidget {
  final OrganizationModel organization;

  const OrganizationVerificationDialog({
    super.key,
    required this.organization,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OrganizationModel organization,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => OrganizationVerificationDialog(organization: organization),
    );
  }

  @override
  ConsumerState<OrganizationVerificationDialog> createState() =>
      _OrganizationVerificationDialogState();
}

class _OrganizationVerificationDialogState
    extends ConsumerState<OrganizationVerificationDialog> {
  late OrganizationModel _organization;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _organization = widget.organization;
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _approve() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await ref.read(organizationRepositoryProvider).verifyOrganization(
            widget.organization.id,
            verifiedBy: currentUser?.email ?? 'SuperAdmin',
          );
      ref.invalidate(organizationsStreamProvider);
      ref.invalidate(organizationsFutureProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${widget.organization.name} has been verified and activated for public join & payments!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Organisation?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will mark the organisation as rejected and prevent it from appearing publicly or accepting member payments.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'e.g. Unverified identity or suspicious name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        await ref.read(organizationRepositoryProvider).rejectOrganization(
              widget.organization.id,
              reason: reasonController.text.trim(),
            );
        ref.invalidate(organizationsStreamProvider);
        ref.invalidate(organizationsFutureProvider);
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              content: Text('${widget.organization.name} has been marked as rejected.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = e.toString();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final org = _organization;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned Dialog Header
            _buildDialogHeader(theme),
            const Divider(height: 1),

            // Scrollable Dossier Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrganizationHeroCard(theme, org),
                    const SizedBox(height: 16),
                    _buildExecutiveIdentificationSection(theme, org),
                    const SizedBox(height: 16),
                    _buildCommunityCredentialsSection(theme, org),
                    const SizedBox(height: 16),
                    _buildReceivingBankAuditSection(theme, org),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(theme, _error!),
                    ],
                  ],
                ),
              ),
            ),

            // Pinned Bottom Actions
            const Divider(height: 1),
            _buildBottomActionBar(theme, org),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppTheme.brandGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Platform Verification Review',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close dialog',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationHeroCard(ThemeData theme, OrganizationModel org) {
    final (statusColor, statusBg, statusIcon, statusText) = switch (org.verificationStatus) {
      'verified' => (
          Colors.green.shade800,
          Colors.green.shade50,
          Icons.verified_rounded,
          'VERIFIED & ACTIVE'
        ),
      'rejected' => (
          Colors.red.shade800,
          Colors.red.shade50,
          Icons.cancel_rounded,
          'REJECTED'
        ),
      _ => (
          Colors.amber.shade900,
          Colors.amber.shade50,
          Icons.hourglass_top_rounded,
          'PENDING REVIEW'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppTheme.brandGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => _copyToClipboard('@${org.slug}', 'Slug'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '@${org.slug}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveIdentificationSection(ThemeData theme, OrganizationModel org) {
    final founderHasId = org.founderNinOrBvn?.trim().isNotEmpty == true;
    final secretaryHasId = org.secretaryNinOrBvn?.trim().isNotEmpty == true;

    return _buildSectionCard(
      theme: theme,
      title: 'Executive Identification',
      icon: Icons.badge_outlined,
      children: [
        _buildCredentialTile(
          theme: theme,
          label: 'FOUNDER (PRESIDENT) IDENTITY',
          value: founderHasId ? org.founderNinOrBvn! : 'Not Provided (Unverified)',
          isVerified: founderHasId,
          statusLabel: founderHasId ? 'Captured' : 'Missing',
          onCopy: founderHasId ? () => _copyToClipboard(org.founderNinOrBvn!, 'Founder NIN/BVN') : null,
        ),
        const Divider(height: 16),
        _buildCredentialTile(
          theme: theme,
          label: 'GENERAL SECRETARY IDENTITY',
          value: secretaryHasId ? org.secretaryNinOrBvn! : 'Pending Co-Sign Verification',
          isVerified: secretaryHasId,
          statusLabel: secretaryHasId ? 'Co-Signed' : 'Pending Co-Sign',
          isPendingNotice: !secretaryHasId,
          onCopy: secretaryHasId ? () => _copyToClipboard(org.secretaryNinOrBvn!, 'Secretary NIN/BVN') : null,
        ),
      ],
    );
  }

  Widget _buildCommunityCredentialsSection(ThemeData theme, OrganizationModel org) {
    final hasCac = org.cacNumber?.trim().isNotEmpty == true;
    final hasTownUnion = org.townUnionName?.trim().isNotEmpty == true;
    final hasContact = org.townUnionContact?.trim().isNotEmpty == true;

    return _buildSectionCard(
      theme: theme,
      title: 'Community & Legal Credentials',
      icon: Icons.gavel_outlined,
      children: [
        _buildCredentialTile(
          theme: theme,
          label: 'CAC REGISTRATION NUMBER',
          value: hasCac ? org.cacNumber! : 'Not Provided',
          isVerified: hasCac,
          statusLabel: hasCac ? 'Registered' : 'Unregistered',
          onCopy: hasCac ? () => _copyToClipboard(org.cacNumber!, 'CAC Number') : null,
        ),
        const Divider(height: 16),
        _buildCredentialTile(
          theme: theme,
          label: 'TOWN UNION / APEX BODY',
          value: hasTownUnion ? org.townUnionName! : 'Not Specified',
          isVerified: hasTownUnion,
          statusLabel: hasTownUnion ? 'Specified' : null,
          onCopy: hasTownUnion ? () => _copyToClipboard(org.townUnionName!, 'Town Union') : null,
        ),
        if (hasContact) ...[
          const Divider(height: 16),
          _buildCredentialTile(
            theme: theme,
            label: 'TOWN UNION ENDORSEMENT CONTACT',
            value: org.townUnionContact!,
            isVerified: true,
            statusLabel: 'Contact Provided',
            onCopy: () => _copyToClipboard(org.townUnionContact!, 'Endorsement Contact'),
          ),
        ],
      ],
    );
  }

  Widget _buildReceivingBankAuditSection(ThemeData theme, OrganizationModel org) {
    final hasBankConfigured = org.bankName?.trim().isNotEmpty == true &&
        org.accountNumber?.trim().isNotEmpty == true;
    final bankInfo = hasBankConfigured
        ? '${org.bankName}  •  ${org.accountNumber}'
        : 'Not Configured';

    return _buildSectionCard(
      theme: theme,
      title: 'Receiving Bank Account Audit',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        _buildCredentialTile(
          theme: theme,
          label: 'BANK & ACCOUNT NUMBER',
          value: bankInfo,
          isVerified: hasBankConfigured,
          onCopy: hasBankConfigured && org.accountNumber != null
              ? () => _copyToClipboard(org.accountNumber!, 'Account Number')
              : null,
        ),
        const Divider(height: 16),
        _buildCredentialTile(
          theme: theme,
          label: 'ACCOUNT BENEFICIARY NAME',
          value: org.accountName?.trim().isNotEmpty == true
              ? org.accountName!
              : 'Not Configured',
          isVerified: org.accountName?.trim().isNotEmpty == true,
          onCopy: org.accountName != null
              ? () => _copyToClipboard(org.accountName!, 'Account Name')
              : null,
        ),
        const SizedBox(height: 12),
        // Association Name Match Callout Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: org.isBankVerified
                ? Colors.green.shade50
                : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: org.isBankVerified
                  ? Colors.green.shade300
                  : Colors.amber.shade300,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                org.isBankVerified
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                size: 18,
                color: org.isBankVerified
                    ? Colors.green.shade800
                    : Colors.amber.shade900,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  org.isBankVerified
                      ? 'Association Name Verified: Bank account name matches registered Age Grade records.'
                      : 'Association Check Pending: Ensure registered bank account belongs to ${org.name} prior to activating.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: org.isBankVerified
                        ? Colors.green.shade900
                        : Colors.amber.shade900,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final updated = await EditOrganizationBankDialog.show(
                context,
                organization: org,
              );
              if (updated == true && mounted) {
                try {
                  final latest = await ref
                      .read(organizationRepositoryProvider)
                      .getOrganizationById(org.id);
                  if (latest != null && mounted) {
                    setState(() => _organization = latest);
                  }
                } catch (_) {}
                ref.invalidate(organizationsStreamProvider);
                ref.invalidate(currentOrganizationProvider);
              }
            },
            icon: const Icon(Icons.account_balance, size: 16),
            label: Text(
              hasBankConfigured
                  ? 'Update Bank Account Details'
                  : 'Set Up Receiving Bank Account',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal.shade800,
              side: BorderSide(color: Colors.teal.shade300),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Section Card Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialTile({
    required ThemeData theme,
    required String label,
    required String value,
    required bool isVerified,
    String? statusLabel,
    bool isPendingNotice = false,
    VoidCallback? onCopy,
  }) {
    final statusColor = isPendingNotice
        ? Colors.amber.shade800
        : (isVerified ? Colors.green.shade800 : Colors.red.shade700);

    final statusBg = isPendingNotice
        ? Colors.amber.shade50
        : (isVerified ? Colors.green.shade50 : Colors.red.shade50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isVerified
                      ? theme.colorScheme.onSurface
                      : (isPendingNotice
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.red.shade700),
                ),
              ),
            ),
            if (onCopy != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Copy',
                icon: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onCopy,
              ),
            if (statusLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(ThemeData theme, OrganizationModel org) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 530;

          final closeButton = OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          );

          final rejectButton = org.verificationStatus != 'rejected'
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _reject,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Reject'),
                )
              : null;

          final verifyButton = !org.isVerified
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _approve,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user_rounded, size: 16),
                  label: const Text(
                    'Verify & Activate',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                )
              : null;

          if (isCompact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?verifyButton,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: closeButton),
                    if (rejectButton != null) ...[
                      const SizedBox(width: 8),
                      Expanded(child: rejectButton),
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              closeButton,
              const Spacer(),
              if (rejectButton != null) ...[
                rejectButton,
                const SizedBox(width: 8),
              ],
              ?verifyButton,
            ],
          );
        },
      ),
    );
  }
}

