// features/payments/views/payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/payments/views/transfer_proof_screen.dart';
import 'package:cls/features/dashboard/controllers/member_dashboard_provider.dart'
    show paymentRepositoryProvider;

final paymentHistoryProvider = StreamProvider.autoDispose
    .family<List<PaymentModel>, String>((ref, memberId) {
      final repo = ref.watch(paymentRepositoryProvider);
      return repo.getMemberPayments(memberId);
    });

class PaymentHistoryScreen extends ConsumerWidget {
  final String memberId;

  const PaymentHistoryScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentHistoryProvider(memberId));
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy \u2022 h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History'), centerTitle: true),
      body: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('No payments yet', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentHistoryCard(
                payment: payment,
                currency: currency,
                dateFormat: dateFormat,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends ConsumerWidget {
  final PaymentModel payment;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _PaymentHistoryCard({
    required this.payment,
    required this.currency,
    required this.dateFormat,
  });

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

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return 'Online (Paystack)';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  Widget _buildReceiptButton(BuildContext context, PaymentModel payment) {
    return IconButton(
      icon: Icon(
        Icons.receipt,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () async {
        if (payment.transferProofUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransferProofScreen(payment: payment),
            ),
          );
        }
      },
      tooltip: 'View Transfer Proof',
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
    );
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return 'Approved';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    currency.format(payment.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(payment.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(payment.status),
                    style: TextStyle(
                      color: _statusColor(payment.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (payment.method == PaymentMethod.bankTransfer &&
                    payment.transferProofUrl != null) ...[
                  const SizedBox(width: 8),
                  _buildReceiptButton(context, payment),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payment, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _methodLabel(payment.method),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(payment.createdAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (payment.allocations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text(
                'Allocations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              ...payment.allocations.map((alloc) {
                return Text(
                  '• ${alloc.obligationId.substring(0, alloc.obligationId.length > 8 ? 8 : alloc.obligationId.length)}: ${currency.format(alloc.amount)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                );
              }),
            ],
            if (payment.paystackReference != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ref: ${payment.paystackReference}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
