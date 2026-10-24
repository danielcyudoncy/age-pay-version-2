import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/controllers/auth_provider.dart';
import '../controllers/provost_provider.dart';
import '../models/penalty_waiver_model.dart';

class PenaltyWaiverApprovalQueueCard extends ConsumerStatefulWidget {
  final String organizationId;

  const PenaltyWaiverApprovalQueueCard({
    super.key,
    required this.organizationId,
  });

  @override
  ConsumerState<PenaltyWaiverApprovalQueueCard> createState() =>
      _PenaltyWaiverApprovalQueueCardState();
}

class _PenaltyWaiverApprovalQueueCardState
    extends ConsumerState<PenaltyWaiverApprovalQueueCard> {
  final Set<String> _processingWaivers = {};

  final _currencyFormat =
      NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  Future<void> _approve(PenaltyWaiverModel waiver, String presidentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Penalty Pardon?'),
        content: Text(
          'Countersign and approve waiver of ${_currencyFormat.format(waiver.amount)} for ${waiver.memberName}?\n\nThis will zero out the fine on their statement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Countersign & Pardon'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingWaivers.add(waiver.id));
    try {
      final controller = ref.read(provostControllerProvider);
      await controller.approvePenaltyWaiver(
        waiverId: waiver.id,
        obligationId: waiver.obligationId,
        reviewedBy: presidentName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade700,
            content: Text(
              'Pardon approved for ${waiver.memberName}. Fine zeroed out.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to approve waiver: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingWaivers.remove(waiver.id));
      }
    }
  }

  Future<void> _reject(PenaltyWaiverModel waiver, String presidentName) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Penalty Pardon?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify why this penalty waiver for ${waiver.memberName} is rejected:',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Inadequate justification provided...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject Pardon'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingWaivers.add(waiver.id));
    try {
      final controller = ref.read(provostControllerProvider);
      await controller.rejectPenaltyWaiver(
        waiverId: waiver.id,
        obligationId: waiver.obligationId,
        reviewedBy: presidentName,
        rejectionReason: reasonController.text.trim().isEmpty
            ? 'Rejected by President'
            : reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pardon rejected for ${waiver.memberName}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to reject waiver: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingWaivers.remove(waiver.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiversAsync =
        ref.watch(pendingWaiversStreamProvider(widget.organizationId));
    final authState = ref.watch(authProvider);
    final presidentName = authState.valueOrNull?.displayName ?? 'President';

    return waiversAsync.when(
      data: (waivers) {
        if (waivers.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.shade100.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.healing_outlined,
                        color: Colors.teal.shade900,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Penalty Pardon Requests',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF004D40),
                            ),
                          ),
                          Text(
                            'Provost requested disciplinary waivers awaiting countersignature',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${waivers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: waivers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final waiver = waivers[idx];
                    final isProcessing =
                        _processingWaivers.contains(waiver.id);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
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
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                _currencyFormat.format(waiver.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Member: ${waiver.memberName}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'Requested by: ${waiver.requestedBy} • ${DateFormat('MMM d').format(waiver.requestedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Excuse: ${waiver.reason}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: isProcessing
                                    ? null
                                    : () => _reject(waiver, presidentName),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(
                                      color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Reject',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _approve(waiver, presidentName),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                                label: const Text('Countersign Pardon',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
