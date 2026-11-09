import 'package:cls/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'organization_verification_dialog.dart';
import 'license_verification_dialog.dart';
import 'edit_organization_bank_dialog.dart';

class OrganizationListItem extends ConsumerWidget {
  final OrganizationModel organization;
  final VoidCallback onToggleStatus;
  final VoidCallback onToggleJoin;
  final VoidCallback onEdit;
  final VoidCallback onAddBranch;
  final VoidCallback onDelete;
  final ValueChanged<BranchModel>? onBranchTap;

  const OrganizationListItem({
    super.key,
    required this.organization,
    required this.onToggleStatus,
    required this.onToggleJoin,
    required this.onEdit,
    required this.onAddBranch,
    required this.onDelete,
    this.onBranchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(branchesStreamFamily(organization.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Organization Info & Popup Menu Actions (Tier 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: organization.isActive
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  child: Icon(
                    organization.isActive
                        ? Icons.business
                        : Icons.business_outlined,
                    color: organization.isActive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organization.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusPill(context, isActive: organization.isActive),
                          _buildVerificationPill(context, status: organization.verificationStatus),
                          _buildBankPill(context, organization: organization),
                          _buildLicensePill(context, organization: organization),
                          _buildJoinPill(context, openForJoin: organization.openForJoin),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '@${organization.slug}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Organisation options',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'verify':
                        OrganizationVerificationDialog.show(
                          context,
                          organization: organization,
                        );
                        break;
                      case 'license':
                        LicenseVerificationDialog.show(
                          context,
                          organization: organization,
                        );
                        break;
                      case 'bank':
                        EditOrganizationBankDialog.show(
                          context,
                          organization: organization,
                        );
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'toggle_join':
                        onToggleJoin();
                        break;
                      case 'toggle_status':
                        onToggleStatus();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'verify',
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 20, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(child: Text('Review & Verify')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'license',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 20, color: Colors.amber),
                          SizedBox(width: 12),
                          Expanded(child: Text('Review License Payment')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'bank',
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_outlined, size: 20, color: Colors.teal),
                          SizedBox(width: 12),
                          Expanded(child: Text('Bank Account Setup')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Edit details')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_join',
                      child: Row(
                        children: [
                          Icon(
                            organization.openForJoin
                                ? Icons.no_accounts_outlined
                                : Icons.login_outlined,
                            size: 20,
                            color: organization.openForJoin
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              organization.openForJoin
                                  ? 'Close Join'
                                  : 'Open Join',
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            organization.isActive
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: organization.isActive
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              organization.isActive
                                  ? 'Deactivate'
                                  : 'Activate',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (organization.isLicensePendingVerification) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.statusBg(context, Colors.amber),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.statusColor(context, Colors.amber).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      color: AppTheme.statusColor(context, Colors.amber),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Annual license renewal payment pending review',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.statusColor(context, Colors.amber),
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => LicenseVerificationDialog.show(
                        context,
                        organization: organization,
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppTheme.statusBg(context, Colors.amber),
                        foregroundColor: AppTheme.statusColor(context, Colors.amber),
                      ),
                      child: const Text(
                        'Review',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tier 2: Metadata / Contact & Banking details
            if (organization.contactEmail.isNotEmpty ||
                organization.contactPhone.isNotEmpty ||
                organization.address.isNotEmpty ||
                (organization.bankName != null && organization.bankName!.trim().isNotEmpty)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    if (organization.contactEmail.isNotEmpty || organization.contactPhone.isNotEmpty)
                      Row(
                        children: [
                          if (organization.contactEmail.isNotEmpty)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      organization.contactEmail,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (organization.contactPhone.isNotEmpty) ...[
                            if (organization.contactEmail.isNotEmpty) const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  organization.contactPhone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    if (organization.address.isNotEmpty) ...[
                      if (organization.contactEmail.isNotEmpty || organization.contactPhone.isNotEmpty)
                        const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              organization.address,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (organization.bankName != null &&
                        organization.bankName!.trim().isNotEmpty) ...[
                      if (organization.contactEmail.isNotEmpty ||
                          organization.contactPhone.isNotEmpty ||
                          organization.address.isNotEmpty)
                        const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance,
                            size: 13,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${organization.bankName!} • ${organization.accountNumber ?? ''}${organization.accountName?.isNotEmpty == true ? " (${organization.accountName!})" : ""}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Branches Section Header (Tier 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Branches',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    branchesAsync.maybeWhen(
                      data: (branches) => branches.isNotEmpty
                          ? Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${branches.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onAddBranch,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Add Branch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Branches Badges List
            branchesAsync.when(
              data: (branches) {
                if (branches.isEmpty) {
                  return Text(
                    'No branches registered yet under this organisation.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: branches.map((branch) {
                    return InkWell(
                      onTap: () => onBranchTap?.call(branch),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                branch.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (branch.city.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${branch.city})',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Text(
                'Could not load branches',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, {required bool isActive}) {
    final color = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinPill(BuildContext context, {required bool openForJoin}) {
    final color = openForJoin ? Colors.blue : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            openForJoin ? Icons.check_circle_outline : Icons.lock_outline,
            size: 11,
            color: openForJoin ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            openForJoin ? 'Join Open' : 'Join Closed',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: openForJoin ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPill(BuildContext context, {required String status}) {
    final isVerified = status == 'verified';
    final isRejected = status == 'rejected';
    final color = isVerified
        ? Colors.green
        : (isRejected ? Colors.red : Colors.amber);
    final label = isVerified
        ? 'Verified'
        : (isRejected ? 'Rejected' : 'Pending Review');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.statusBg(context, color),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.statusColor(context, color).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified
                ? Icons.verified
                : (isRejected ? Icons.cancel : Icons.hourglass_top),
            size: 11,
            color: AppTheme.statusColor(context, color),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.statusColor(context, color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicensePill(
    BuildContext context, {
    required OrganizationModel organization,
  }) {
    final isPending = organization.isLicensePendingVerification;
    final isActive = organization.isLicenseActive;
    final color = isPending
        ? Colors.amber
        : (isActive ? Colors.teal : Colors.red);
    final label = isPending
        ? 'License: Pending'
        : (isActive
            ? (organization.subscriptionExpiresAt != null
                ? 'License: ${organization.licenseDaysRemaining}d'
                : 'License: Active')
            : 'License: Expired');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.statusBg(context, color),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.statusColor(context, color).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending
                ? Icons.hourglass_top
                : (isActive ? Icons.verified_user : Icons.warning_amber),
            size: 11,
            color: AppTheme.statusColor(context, color),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.statusColor(context, color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankPill(
    BuildContext context, {
    required OrganizationModel organization,
  }) {
    final hasBank = organization.bankName != null &&
        organization.bankName!.trim().isNotEmpty &&
        organization.accountNumber != null &&
        organization.accountNumber!.trim().isNotEmpty;
    final color = hasBank ? Colors.teal : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.statusBg(context, color),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.statusColor(context, color).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasBank ? Icons.account_balance : Icons.account_balance_outlined,
            size: 11,
            color: AppTheme.statusColor(context, color),
          ),
          const SizedBox(width: 3),
          Text(
            hasBank ? organization.bankName! : 'No Bank',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.statusColor(context, color),
            ),
          ),
        ],
      ),
    );
  }
}
