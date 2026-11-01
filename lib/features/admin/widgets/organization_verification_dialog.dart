import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/organization_model.dart';
import '../controllers/admin_provider.dart';

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
      builder: (_) => OrganizationVerificationDialog(organization: organization),
    );
  }

  @override
  ConsumerState<OrganizationVerificationDialog> createState() =>
      _OrganizationVerificationDialogState();
}

class _OrganizationVerificationDialogState
    extends ConsumerState<OrganizationVerificationDialog> {
  bool _isLoading = false;
  String? _error;

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
        title: const Text('Reject Organization?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will mark the organization as rejected and prevent it from appearing publicly or accepting payments.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'e.g. Unverified identity or suspicious name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              content: Text('${widget.organization.name} has been rejected.'),
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
    final org = widget.organization;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform Verification Review',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Zero-Trust Organization Compliance',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    _infoRow('Age Grade', org.name, isBold: true),
                    const SizedBox(height: 8),
                    _infoRow('Platform Slug', '@${org.slug}'),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Verification Status',
                      org.verificationStatus.toUpperCase().replaceAll('_', ' '),
                      color: org.isVerified
                          ? Colors.green.shade800
                          : (org.verificationStatus == 'rejected'
                              ? Colors.red.shade800
                              : Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Executive Identity Credentials
              Text(
                'EXECUTIVE IDENTIFICATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      'Founder (President) NIN/BVN',
                      org.founderNinOrBvn?.isNotEmpty == true
                          ? org.founderNinOrBvn!
                          : 'Not Provided (Unverified)',
                      color: org.founderNinOrBvn?.isNotEmpty == true
                          ? Colors.black87
                          : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'General Secretary NIN/BVN',
                      org.secretaryNinOrBvn?.isNotEmpty == true
                          ? org.secretaryNinOrBvn!
                          : 'Pending Co-Sign Verification',
                      color: org.secretaryNinOrBvn?.isNotEmpty == true
                          ? Colors.black87
                          : Colors.grey.shade700,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Community & Legal Credentials
              Text(
                'COMMUNITY & LEGAL CREDENTIALS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      'CAC Registration Number',
                      org.cacNumber?.isNotEmpty == true
                          ? org.cacNumber!
                          : 'Not Provided',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Town Union / Apex Body',
                      org.townUnionName?.isNotEmpty == true
                          ? org.townUnionName!
                          : 'Not Specified',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Town Union Endorsement Contact',
                      org.townUnionContact?.isNotEmpty == true
                          ? org.townUnionContact!
                          : 'Not Specified',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bank Account Matching Credentials
              Text(
                'RECEIVING BANK ACCOUNT AUDIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      'Bank & Account Number',
                      '${org.bankName ?? "Not Configured"} - ${org.accountNumber ?? ""}',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Account Name',
                      org.accountName ?? 'Not Configured',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Association Match Status',
                      org.isBankVerified
                          ? '✓ Verified Association Match'
                          : '⚠️ Pending Association Check',
                      color: org.isBankVerified ? Colors.green.shade700 : Colors.amber.shade900,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  ),
                ),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (org.verificationStatus != 'rejected')
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: _isLoading ? null : _reject,
                        child: const Text('Reject'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (!org.isVerified)
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                        onPressed: _isLoading ? null : _approve,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Verify & Activate'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
