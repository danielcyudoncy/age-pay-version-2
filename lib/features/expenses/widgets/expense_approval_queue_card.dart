import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../controllers/expense_provider.dart';
import '../models/expense_model.dart';

class ExpenseApprovalQueueCard extends ConsumerStatefulWidget {
  final String organizationId;

  const ExpenseApprovalQueueCard({
    super.key,
    required this.organizationId,
  });

  @override
  ConsumerState<ExpenseApprovalQueueCard> createState() =>
      _ExpenseApprovalQueueCardState();
}

class _ExpenseApprovalQueueCardState
    extends ConsumerState<ExpenseApprovalQueueCard> {
  final Set<String> _processingIds = {};

  Future<void> _approve(ExpenseModel expense, UserRole role, String uid, String name) async {
    setState(() => _processingIds.add(expense.id));
    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.approveExpense(
        expenseId: expense.id,
        role: role,
        userId: uid,
        userName: name,
      );
      ref.invalidate(expensesStreamProvider);
      ref.invalidate(pendingExpensesStreamProvider);
      ref.invalidate(expenseTotalProvider);
      ref.invalidate(pendingExpenseTotalProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('Expense "${expense.title}" signed off successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to approve expense: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(expense.id));
      }
    }
  }

  Future<void> _reject(ExpenseModel expense, UserRole role, String uid, String name) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject ₦${expense.amount.toStringAsFixed(0)} for "${expense.title}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Budget exceeded or missing invoice',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Expense', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _processingIds.add(expense.id));
      try {
        final repo = ref.read(expenseRepositoryProvider);
        await repo.rejectExpense(
          expenseId: expense.id,
          role: role,
          userId: uid,
          userName: name,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : 'Rejected by executive review',
        );
        ref.invalidate(expensesStreamProvider);
        ref.invalidate(pendingExpensesStreamProvider);
        ref.invalidate(expenseTotalProvider);
        ref.invalidate(pendingExpenseTotalProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('Expense "${expense.title}" rejected.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('Failed to reject: $e'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _processingIds.remove(expense.id));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final userRole = user.role;
    final isSigner = userRole == UserRole.president ||
        userRole == UserRole.vicePresident ||
        userRole == UserRole.financialSecretary ||
        userRole == UserRole.secretary ||
        userRole == UserRole.viceSecretary;

    final expensesAsync = ref.watch(pendingExpensesStreamProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return expensesAsync.when(
      data: (allPending) {
        final pending = allPending.where((e) {
          if (widget.organizationId.isNotEmpty &&
              e.organizationId.isNotEmpty &&
              e.organizationId != widget.organizationId) {
            return false;
          }
          return true;
        }).toList();

        if (pending.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.amber.shade300, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.rate_review_outlined,
                            color: Colors.amber.shade900,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pending Expense Approvals',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Requires President, Fin. Sec & Secretary sign-offs',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${pending.length} Pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...pending.map((expense) {
                  final isProcessing = _processingIds.contains(expense.id);
                  final hasCurrentUserSigned = expense.isRoleApproved(userRole);
                  final approvalCount = expense.approvedCount;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                expense.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              currency.format(expense.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        if (expense.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            expense.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        // 3 Signatures Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _signatureBadge(
                              roleLabel: 'President',
                              isApproved: expense.isPresidentApproved,
                              approvedByName: expense.approvals['president']?['byName'] as String?,
                            ),
                            _signatureBadge(
                              roleLabel: 'Fin. Sec',
                              isApproved: expense.isFinancialSecretaryApproved,
                              approvedByName: expense.approvals['financialSecretary']?['byName'] as String?,
                            ),
                            _signatureBadge(
                              roleLabel: 'Secretary',
                              isApproved: expense.isSecretaryApproved,
                              approvedByName: expense.approvals['secretary']?['byName'] as String?,
                            ),
                          ],
                        ),
                        if (isSigner && !hasCurrentUserSigned) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: isProcessing
                                    ? null
                                    : () => _reject(
                                          expense,
                                          userRole,
                                          user.uid,
                                          user.displayName,
                                        ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                ),
                                child: const Text('Reject', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _approve(
                                          expense,
                                          userRole,
                                          user.uid,
                                          user.displayName,
                                        ),
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 14),
                                label: Text(
                                  'Approve ($approvalCount/3)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ] else if (hasCurrentUserSigned) ...[
                          const SizedBox(height: 8),
                          Text(
                            '✓ You have approved this expense. Waiting for remaining sign-offs.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _signatureBadge({
    required String roleLabel,
    required bool isApproved,
    String? approvedByName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isApproved ? Colors.green.shade400 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.hourglass_empty,
            size: 13,
            color: isApproved ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            isApproved
                ? '$roleLabel (Signed)'
                : '$roleLabel (Pending)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isApproved ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
