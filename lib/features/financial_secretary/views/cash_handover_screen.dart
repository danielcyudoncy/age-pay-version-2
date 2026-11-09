import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../models/cash_handover_model.dart';
import '../controllers/cash_handover_provider.dart';
import '../controllers/financial_secretary_dashboard_provider.dart';

class CashHandoverScreen extends ConsumerStatefulWidget {
  const CashHandoverScreen({super.key});

  @override
  ConsumerState<CashHandoverScreen> createState() => _CashHandoverScreenState();
}

class _CashHandoverScreenState extends ConsumerState<CashHandoverScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showInitiateDialog(double defaultAmount) {
    _amountController.text = defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '';
    _notesController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Hand Over Cash to Treasurer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a digital handover voucher for cash collected at meetings. The Treasurer will verify and confirm receipt.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Handover Amount (₦) *',
                    hintText: 'e.g. 50000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting / Voucher Notes *',
                    hintText: 'e.g. October 2026 general meeting dues',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final amount = double.tryParse(_amountController.text) ?? 0.0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }

                      final user = ref.read(authProvider).valueOrNull;
                      if (user == null) return;

                      setDialogState(() => _isSubmitting = true);
                      try {
                        final repo = ref.read(cashHandoverRepositoryProvider);
                        final handover = CashHandoverModel(
                          id: '',
                          organizationId: user.organizationId,
                          branchId: user.branchId,
                          amount: amount,
                          handedOverBy: user.displayName.isNotEmpty
                              ? user.displayName
                              : 'Financial Secretary',
                          handedOverById: user.uid,
                          handedOverAt: DateTime.now(),
                          notes: _notesController.text.trim().isNotEmpty
                              ? _notesController.text.trim()
                              : 'Meeting cash collection handover',
                          createdBy: user.uid,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await repo.createHandover(handover);

                        ref.invalidate(cashHandoversStreamProvider);
                        ref.invalidate(pendingCashHandoversStreamProvider);

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cash handover voucher submitted to Treasurer!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() => _isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary(context),
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit Handover'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final dashboardAsync = ref.watch(financialSecretaryDashboardProvider);
    final handoversAsync = ref.watch(cashHandoversStreamProvider);

    final cashCollected = dashboardAsync.valueOrNull?.cashCollected ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Handover Vouchers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInitiateDialog(cashCollected),
        backgroundColor: AppTheme.primary(context),
        icon: const Icon(Icons.sync_alt, color: Colors.white),
        label: const Text('Handover to Treasurer', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments, color: Colors.teal, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Cash in Hand',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        currency.format(cashCollected),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showInitiateDialog(cashCollected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Handover'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: handoversAsync.when(
              data: (handovers) {
                if (handovers.isEmpty) {
                  return const Center(
                    child: Text('No cash handovers recorded yet.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: handovers.length,
                  itemBuilder: (ctx, index) {
                    final h = handovers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  currency.format(h.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.teal,
                                  ),
                                ),
                                _HandoverBadge(status: h.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Handed over by: ${h.handedOverBy} • ${dateFormat.format(h.handedOverAt)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (h.notes != null && h.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Voucher: ${h.notes}', style: const TextStyle(fontSize: 13)),
                            ],
                            if (h.status == CashHandoverStatus.accepted) ...[
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Confirmed by Treasurer (${h.receivedBy ?? "Treasurer"})\n'
                                      'Deposited to: ${h.bankName ?? "Bank"} ${h.bankAccountNumber ?? ""}',
                                      style: const TextStyle(fontSize: 11, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoverBadge extends StatelessWidget {
  final CashHandoverStatus status;
  const _HandoverBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case CashHandoverStatus.accepted:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Accepted & Deposited';
        break;
      case CashHandoverStatus.pending:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'Awaiting Treasurer';
        break;
      case CashHandoverStatus.rejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Disputed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
