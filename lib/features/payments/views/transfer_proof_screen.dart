// features/payments/views/transfer_proof_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/payment_model.dart';

class TransferProofScreen extends StatelessWidget {
  final PaymentModel payment;

  const TransferProofScreen({super.key, required this.payment});

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return 'Online';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
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
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Proof'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Payment ID', value: payment.id),
            _DetailRow(label: 'Amount', value: currency.format(payment.amount)),
            _DetailRow(label: 'Method', value: _methodLabel(payment.method)),
            _DetailRow(label: 'Status', value: _statusLabel(payment.status)),
            const SizedBox(height: 16),
            if (payment.transferProofUrl != null) ...[
              const Text(
                'Transfer Receipt:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  payment.transferProofUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Allocated Obligations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (payment.allocations.isEmpty)
              Text(
                'No allocations',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...payment.allocations.map(
                (alloc) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(alloc.obligationId),
                    trailing: Text(currency.format(alloc.amount)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(payment.createdAt)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
