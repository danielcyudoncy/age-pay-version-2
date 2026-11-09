import 'package:cls/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/controllers/admin_provider.dart';
import '../../dashboard/controllers/president_dashboard_provider.dart';
import '../../dashboard/controllers/treasurer_dashboard_provider.dart';
import '../models/member_model.dart';

class DeleteMemberDialog extends ConsumerStatefulWidget {
  final MemberModel member;

  const DeleteMemberDialog({
    super.key,
    required this.member,
  });

  static Future<bool?> show(
    BuildContext context, {
    required MemberModel member,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteMemberDialog(member: member),
    );
  }

  @override
  ConsumerState<DeleteMemberDialog> createState() => _DeleteMemberDialogState();
}

class _DeleteMemberDialogState extends ConsumerState<DeleteMemberDialog> {
  bool _isCheckingLedger = true;
  int _paymentCount = 0;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkMemberFinancialHistory();
  }

  Future<void> _checkMemberFinancialHistory() async {
    try {
      final repo = ref.read(memberRepositoryProvider);
      final count = await repo.getMemberPaymentCount(
        widget.member.id,
        userId: widget.member.userId,
      );
      if (mounted) {
        setState(() {
          _paymentCount = count;
          _isCheckingLedger = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentCount = 0;
          _isCheckingLedger = false;
        });
      }
    }
  }

  Future<void> _handleSoftDelete() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(memberRepositoryProvider);
      await repo.softDeleteMember(
        widget.member.id,
        userId: widget.member.userId,
      );
      _invalidateAndClose(
        '${widget.member.fullName} has been deactivated and archived.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handlePermanentPurge() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(memberRepositoryProvider);
      await repo.purgeMemberPermanently(
        widget.member.id,
        userId: widget.member.userId,
      );
      _invalidateAndClose(
        '${widget.member.fullName} was permanently deleted.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _invalidateAndClose(String message) {
    ref.invalidate(membersStreamProvider);
    ref.invalidate(presidentMembersStreamProvider);
    ref.invalidate(allUsersStreamProvider);

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.statusColor(context, Colors.green),
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = widget.member;
    final hasBranch = member.branchName != null && member.branchName!.trim().isNotEmpty;
    final branchDisplay = hasBranch ? member.branchName! : 'Direct / Unassigned Branch';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with red shield/delete badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.statusBg(context, Colors.red),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Member',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'SuperAdmin Governance Access',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Member Target Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.statusBg(context, Colors.red),
                      child: Text(
                        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: AppTheme.statusColor(context, Colors.red),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  branchDisplay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ledger Status Verification Callout
              if (_isCheckingLedger)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Verifying financial ledger records...',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_paymentCount > 0)
                // Case 1: Member has financial history
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: AppTheme.statusColor(context, Colors.amber),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Financial History Found ($_paymentCount record(s))',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.statusColor(context, Colors.amber),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Under AgePay financial integrity rules, this member cannot be permanently purged to avoid breaking historical payment audit trails.\n\n'
                        'As a SuperAdmin, deactivating and archiving this member will:\n'
                        '• Immediately remove them from active branch rosters\n'
                        '• Stop all future dues and obligations\n'
                        '• Revoke app login access\n'
                        '• Retain ledger records for accounting audits',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.statusColor(context, Colors.amber),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Case 2: Zero financial history
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 18,
                            color: AppTheme.statusColor(context, Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No Financial Transactions Found',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.statusColor(context, Colors.green),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This member has no recorded payments. As a SuperAdmin with cross-branch governance, you can either archive this member or permanently purge their document from the database.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.statusColor(context, Colors.green),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.statusBg(context, Colors.red),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              if (!_isCheckingLedger)
                _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    if (_paymentCount > 0) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing ? null : _handleSoftDelete,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Deactivate & Archive'),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _isProcessing ? null : _handlePermanentPurge,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Permanently Delete'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                onPressed: _isProcessing ? null : _handleSoftDelete,
                child: const Text('Deactivate Only'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
