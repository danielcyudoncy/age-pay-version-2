// member_widgets.dart
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/core/constants/enums.dart';


class MemberInfoCard extends StatelessWidget {
  final MemberModel member;
  final DateFormat dateFormat;
  final VoidCallback? onEdit;
  final bool canEdit;

  const MemberInfoCard({super.key,
    required this.member,
    required this.dateFormat,
    this.onEdit,
    this.canEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    member.fullName.isNotEmpty ? member.fullName[0] : '?',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit && onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                    tooltip: 'Edit Member',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InfoRow(
              icon: Icons.phone,
              label: 'Phone',
              value: member.phoneNumber,
            ),
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.cake,
              label: 'Date of Birth',
              value: dateFormat.format(member.dateOfBirth),
            ),
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.calendar_today,
              label: 'Joined',
              value: dateFormat.format(member.joinedDate),
            ),
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: member.isActive ? 'Active' : 'Inactive',
              valueColor: member.isActive ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class LevySummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat currency;

  const LevySummaryCard({super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              currency.format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final ObligationStatus status;

  const StatusChip({super.key,required this.status});

  Color _color() {
    switch (status) {
      case ObligationStatus.paid:
        return Colors.green;
      case ObligationStatus.partial:
        return Colors.orange;
      case ObligationStatus.unpaid:
        return Colors.redAccent;
    }
  }

  String _label() {
    switch (status) {
      case ObligationStatus.paid:
        return 'Paid';
      case ObligationStatus.partial:
        return 'Partial';
      case ObligationStatus.unpaid:
        return 'Unpaid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

