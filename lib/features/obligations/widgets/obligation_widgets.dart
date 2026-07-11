// obligation_widgets.dart
library;

import 'package:flutter/material.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:intl/intl.dart';

class ObligationCard extends StatelessWidget {
  final ObligationModel obligation;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const ObligationCard({super.key,
    required this.obligation,
    required this.currency,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      ObligationStatus.unpaid: Colors.red,
      ObligationStatus.partial: Colors.orange,
      ObligationStatus.paid: Colors.green,
    };

    final statusLabels = {
      ObligationStatus.unpaid: 'Unpaid',
      ObligationStatus.partial: 'Partial',
      ObligationStatus.paid: 'Paid',
    };

    final progress = obligation.amount > 0
        ? obligation.paidAmount / obligation.amount
        : 0.0;

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
                    obligation.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    statusLabels[obligation.status] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: statusColors[obligation.status],
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              obligation.description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AmountRow(
                    label: 'Amount',
                    value: currency.format(obligation.amount),
                    isBold: true,
                  ),
                ),
                Expanded(
                  child: AmountRow(
                    label: 'Paid',
                    value: currency.format(obligation.paidAmount),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: AmountRow(
                    label: 'Outstanding',
                    value: currency.format(obligation.outstandingBalance),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                statusColors[obligation.status]!,
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${dateFormat.format(obligation.dueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% paid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColors[obligation.status],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const AmountRow({super.key,
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const SummaryItem({super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

