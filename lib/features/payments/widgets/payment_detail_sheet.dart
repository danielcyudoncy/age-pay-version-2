import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/receipts/controllers/receipt_provider.dart';
import 'package:cls/features/receipts/views/receipt_detail_screen.dart';
import 'package:cls/features/payments/views/transfer_proof_screen.dart';

void showPaymentDetailSheet(
  BuildContext context, {
  required PaymentModel payment,
  String? memberName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PaymentDetailSheet(
      payment: payment,
      memberName: memberName,
    ),
  );
}

class PaymentDetailSheet extends ConsumerWidget {
  final PaymentModel payment;
  final String? memberName;

  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.memberName,
  });

  String _formatReference(String id) {
    if (id.startsWith('PAY-') || id.startsWith('RCP-') || id.startsWith('REC-')) {
      return id;
    }
    if (id.startsWith('pay_')) {
      return 'PAY-${id.substring(4).toUpperCase()}';
    }
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final code = clean.length > 8
        ? clean.substring(0, 8).toUpperCase()
        : clean.toUpperCase();
    return 'PAY-$code';
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.rejected:
        return Colors.red;
    }
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return 'Approved';
      case PaymentStatus.pending:
        return 'Pending Approval';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return 'Online (Paystack)';
      case PaymentMethod.cash:
        return 'Cash in Hand';
      case PaymentMethod.bankTransfer:
        return 'Direct Bank Transfer';
    }
  }

  IconData _methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return Icons.credit_card;
      case PaymentMethod.cash:
        return Icons.payments;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final allObligations = ref.watch(allObligationsProvider).valueOrNull ?? [];
    final receiptAsync = ref.watch(receiptByPaymentIdProvider(payment.id));

    final effectiveMemberName = payment.memberName ?? memberName;
    final displayReference = _formatReference(
      payment.paystackReference ?? payment.id,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet title and close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Hero Card (Amount, Status, Method, Date)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.cardBorder(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      currency.format(payment.amount),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary(context),
                      ),
                    ),
                    if (effectiveMemberName != null &&
                        effectiveMemberName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        effectiveMemberName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(payment.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                payment.status == PaymentStatus.approved
                                    ? Icons.check_circle
                                    : (payment.status == PaymentStatus.pending
                                        ? Icons.access_time
                                        : Icons.cancel),
                                size: 14,
                                color: _statusColor(payment.status),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _statusLabel(payment.status),
                                style: TextStyle(
                                  color: _statusColor(payment.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _methodIcon(payment.method),
                                size: 14,
                                color: Colors.teal.shade800,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _methodLabel(payment.method),
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      dateFormat.format(payment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section: Purpose / What the money is meant for
            Text(
              'What this money is meant for',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),

            // Note/Purpose Box
            if (payment.notes != null && payment.notes!.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.statusBg(context, Colors.amber),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.statusColor(context, Colors.amber)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: AppTheme.statusColor(context, Colors.amber),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Purpose / Note',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  AppTheme.statusColor(context, Colors.amber),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Allocations (if any)
            if (payment.allocations.isNotEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.cardBorder(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Allocated Dues & Levies',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 16),
                      ...payment.allocations.map((alloc) {
                        final matched = allObligations
                            .where((o) => o.id == alloc.obligationId)
                            .firstOrNull;
                        final title = matched?.title ??
                            'Obligation (${alloc.obligationId.substring(0, alloc.obligationId.length > 8 ? 8 : alloc.obligationId.length)})';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currency.format(alloc.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ] else if (payment.notes == null || payment.notes!.trim().isEmpty) ...[
              // If allocations are empty and no note was provided
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: AppTheme.statusColor(context, Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Upfront / Advance payment credited to member wallet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.statusColor(context, Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Audit & Reference Section
            Text(
              'Transaction Information',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reference:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            displayReference,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: displayReference),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reference copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.copy, size: 14, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (payment.verifiedBy != null &&
                      payment.verifiedBy!.isNotEmpty) ...[
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recorded / Verified By:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          payment.verifiedBy!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons (Transfer Proof or Official Receipt)
            if (payment.transferProofUrl != null) ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransferProofScreen(payment: payment),
                  ),
                ),
                icon: const Icon(Icons.image, size: 18),
                label: const Text('View Bank Transfer Receipt'),
              ),
              const SizedBox(height: 10),
            ],

            // Receipt action if available
            receiptAsync.when(
              data: (receipt) {
                if (receipt == null) return const SizedBox.shrink();
                return FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptDetailScreen(receipt: receipt),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: Text('View Official Receipt (${receipt.receiptNumber})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary(context),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
