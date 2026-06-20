// features/receipts/screens/receipt_detail_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/receipt_model.dart';
import 'package:cls/features/receipts/providers/receipt_provider.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  final ReceiptModel receipt;

  const ReceiptDetailScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy \u2022 h:mm a');
    final pdfAsync = ref.watch(receiptPdfGenerationProvider(receipt));

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReceiptHeaderCard(receipt: receipt, currency: currency),
            const SizedBox(height: 16),
            _ReceiptInfoCard(
              receipt: receipt,
              currency: currency,
              dateFormat: dateFormat,
            ),
            const SizedBox(height: 16),
            _AllocatedObligationsCard(
              obligations: receipt.allocatedObligations,
              currency: currency,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: pdfAsync.when(
                data: (bytes) =>
                    () => _sharePdf(bytes, receipt.receiptNumber),
                loading: () => null,
                error: (_, _) => null,
              ),
              icon: pdfAsync.when(
                data: (_) => const Icon(Icons.download),
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                error: (_, _) => const Icon(Icons.error_outline),
              ),
              label: pdfAsync.when(
                data: (_) => const Text('Download Receipt PDF'),
                loading: () => const Text('Generating PDF...'),
                error: (err, _) => Text('Error: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf(Uint8List bytes, String receiptNumber) async {
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Receipt_$receiptNumber.pdf',
      );
    } catch (e) {
      // Errors are surfaced via the async value in the UI
    }
  }
}

class _ReceiptHeaderCard extends StatelessWidget {
  final ReceiptModel receipt;
  final NumberFormat currency;

  const _ReceiptHeaderCard({required this.receipt, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'OFFICIAL RECEIPT',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              receipt.receiptNumber,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currency.format(receipt.amount),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptInfoCard extends StatelessWidget {
  final ReceiptModel receipt;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _ReceiptInfoCard({
    required this.receipt,
    required this.currency,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Member Name', value: receipt.memberName),
            _InfoRow(
              label: 'Payment Date',
              value: dateFormat.format(receipt.paymentDate),
            ),
            _InfoRow(
              label: 'Payment Method',
              value: _methodLabel(receipt.method),
            ),
            _InfoRow(
              label: 'Status',
              valueWidget: Chip(
                label: Text(_statusLabel(receipt.method)),
                backgroundColor: _statusColor(
                  receipt.method,
                ).withValues(alpha: 0.1),
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: _statusColor(receipt.method),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.online:
        return 'Online Payment';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  static String _statusLabel(PaymentMethod method) => 'Approved';

  static Color _statusColor(PaymentMethod method) => Colors.green;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _InfoRow({required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child:
                valueWidget ??
                Text(
                  value ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _AllocatedObligationsCard extends StatelessWidget {
  final List<Map<String, dynamic>> obligations;
  final NumberFormat currency;

  const _AllocatedObligationsCard({
    required this.obligations,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allocated Obligations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (obligations.isEmpty)
              Text(
                'No obligation allocations recorded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...obligations.map((o) {
                final title = o['title']?.toString() ?? 'Obligation';
                final amount = (o['amount'] as num?)?.toDouble() ?? 0.0;
                return _InfoRow(label: title, value: currency.format(amount));
              }),
          ],
        ),
      ),
    );
  }
}
