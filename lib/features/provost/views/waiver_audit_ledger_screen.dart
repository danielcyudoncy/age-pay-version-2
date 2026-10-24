import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/provost_provider.dart';
import '../models/penalty_waiver_model.dart';

class WaiverAuditLedgerScreen extends ConsumerStatefulWidget {
  final String organizationId;

  const WaiverAuditLedgerScreen({
    super.key,
    required this.organizationId,
  });

  @override
  ConsumerState<WaiverAuditLedgerScreen> createState() =>
      _WaiverAuditLedgerScreenState();
}

class _WaiverAuditLedgerScreenState
    extends ConsumerState<WaiverAuditLedgerScreen> {
  PenaltyWaiverStatus? _filterStatus;
  String _searchQuery = '';

  final _currencyFormat =
      NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final waiversAsync =
        ref.watch(provostWaiversStreamProvider(widget.organizationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pardon & Waiver Audit Ledger'),
        backgroundColor: Colors.teal.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Informational audit banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: Colors.teal.shade900, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Immutable financial audit trail. Every penalty pardon is countersigned by the President.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search member or penalty title...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusFilterChip(label: 'All', status: null),
                      const SizedBox(width: 6),
                      _statusFilterChip(
                        label: 'Pending Approval',
                        status: PenaltyWaiverStatus.pendingApproval,
                      ),
                      const SizedBox(width: 6),
                      _statusFilterChip(
                        label: 'Approved (Pardoned)',
                        status: PenaltyWaiverStatus.approved,
                      ),
                      const SizedBox(width: 6),
                      _statusFilterChip(
                        label: 'Rejected',
                        status: PenaltyWaiverStatus.rejected,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Ledger list
          Expanded(
            child: waiversAsync.when(
              data: (waivers) {
                var filtered = waivers;
                if (_filterStatus != null) {
                  filtered =
                      filtered.where((w) => w.status == _filterStatus).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where((w) =>
                          w.memberName.toLowerCase().contains(_searchQuery) ||
                          w.penaltyTitle.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No waiver audit records found.',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final waiver = filtered[index];
                    return _waiverCard(waiver);
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading waiver ledger: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip({
    required String label,
    required PenaltyWaiverStatus? status,
  }) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      selected: isSelected,
      selectedColor: Colors.teal.shade800,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => setState(() => _filterStatus = status),
    );
  }

  Widget _waiverCard(PenaltyWaiverModel waiver) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (waiver.status) {
      case PenaltyWaiverStatus.pendingApproval:
        statusColor = Colors.amber.shade800;
        statusText = 'Pending President Counter-Signature';
        statusIcon = Icons.hourglass_top_outlined;
        break;
      case PenaltyWaiverStatus.approved:
        statusColor = Colors.green.shade700;
        statusText = 'Approved / Pardoned';
        statusIcon = Icons.check_circle_outline;
        break;
      case PenaltyWaiverStatus.rejected:
        statusColor = Colors.red.shade700;
        statusText = 'Waiver Rejected';
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    waiver.penaltyTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  _currencyFormat.format(waiver.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  waiver.memberName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(waiver.requestedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Justification
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Excuse / Justification:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    waiver.reason,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Audit footer
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            if (waiver.reviewedBy != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reviewed by ${waiver.reviewedBy} on ${waiver.reviewedAt != null ? DateFormat('MMM d, yyyy h:mm a').format(waiver.reviewedAt!) : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            if (waiver.rejectionReason != null &&
                waiver.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Rejection note: ${waiver.rejectionReason}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
