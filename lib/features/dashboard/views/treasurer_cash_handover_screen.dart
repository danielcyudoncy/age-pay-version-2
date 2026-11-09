import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/controllers/admin_provider.dart';
import '../../admin/models/organization_model.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../financial_secretary/models/cash_handover_model.dart';
import '../../financial_secretary/controllers/cash_handover_provider.dart';

class TreasurerCashHandoverScreen extends ConsumerStatefulWidget {
  const TreasurerCashHandoverScreen({super.key});

  @override
  ConsumerState<TreasurerCashHandoverScreen> createState() =>
      _TreasurerCashHandoverScreenState();
}

class _TreasurerCashHandoverScreenState
    extends ConsumerState<TreasurerCashHandoverScreen> {
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _slipUrlController = TextEditingController();
  final _notesController = TextEditingController();
  final _disputeReasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _slipUrlController.dispose();
    _notesController.dispose();
    _disputeReasonController.dispose();
    super.dispose();
  }

  Future<void> _showAcceptDialog(CashHandoverModel handover) async {
    // 1. Fetch current organization bank details
    OrganizationModel? org = ref.read(currentOrganizationProvider).valueOrNull;
    if (org == null) {
      try {
        org = await ref.read(currentOrganizationProvider.future);
      } catch (_) {}
    }

    String defaultBankName = '';
    String defaultAccountNumber = '';
    String defaultAccountName = '';

    // Check if the handover voucher belongs to a specific branch with its own bank details
    if (handover.branchId != null && handover.branchId!.isNotEmpty) {
      try {
        final branch = await ref
            .read(branchRepositoryProvider)
            .getBranchById(handover.branchId!);
        if (branch != null &&
            branch.bankName != null &&
            branch.bankName!.trim().isNotEmpty) {
          defaultBankName = branch.bankName!.trim();
          defaultAccountNumber = branch.accountNumber?.trim() ?? '';
          defaultAccountName = branch.accountName?.trim() ?? '';
        }
      } catch (_) {}
    }

    // Fall back to central organization receiving bank details
    if (defaultBankName.isEmpty && org != null) {
      defaultBankName = org.bankName?.trim() ?? '';
      defaultAccountNumber = org.accountNumber?.trim() ?? '';
      defaultAccountName = org.accountName?.trim() ?? org.name;
    }

    _bankNameController.text = defaultBankName;
    _accountNumberController.text = defaultAccountNumber;
    _slipUrlController.clear();
    _notesController.clear();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm Cash Receipt & Deposit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Handover Amount: ₦${NumberFormat("#,##0").format(handover.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
                Text('From: ${handover.handedOverBy}'),
                if (handover.notes != null) Text('Voucher: ${handover.notes}'),
                const Divider(height: 20),
                const Text(
                  'As Treasurer, certify that you received this physical cash and enter the bank deposit destination:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (defaultAccountName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Official Account: $defaultAccountName',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name *',
                    hintText: 'e.g. Zenith Bank, First Bank',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number / Branch Account',
                    hintText: 'e.g. 3012345678',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _slipUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Deposit Reference / Slip URL',
                    hintText: 'e.g. Teller #98421',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Acknowledgment Notes (Optional)',
                    hintText: 'e.g. Counted and verified intact',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: _isProcessing
                  ? null
                  : () async {
                      final user = ref.read(authProvider).valueOrNull;
                      if (user == null) return;

                      setDialogState(() => _isProcessing = true);
                      try {
                        final repo = ref.read(cashHandoverRepositoryProvider);
                        await repo.acceptHandover(
                          handoverId: handover.id,
                          receivedBy: user.displayName.isNotEmpty
                              ? user.displayName
                              : 'Treasurer',
                          receivedById: user.uid,
                          bankName: _bankNameController.text.trim().isNotEmpty
                              ? _bankNameController.text.trim()
                              : null,
                          bankAccountNumber:
                              _accountNumberController.text.trim().isNotEmpty
                                  ? _accountNumberController.text.trim()
                                  : null,
                          depositSlipUrl: _slipUrlController.text.trim().isNotEmpty
                              ? _slipUrlController.text.trim()
                              : null,
                          notes: _notesController.text.trim().isNotEmpty
                              ? _notesController.text.trim()
                              : null,
                        );

                        ref.invalidate(cashHandoversStreamProvider);
                        ref.invalidate(pendingCashHandoversStreamProvider);

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cash handover accepted and verified into bank!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() => _isProcessing = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary(context),
                foregroundColor: Colors.white,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Confirm & Deposit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisputeDialog(CashHandoverModel handover) {
    _disputeReasonController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Dispute / Return Handover'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Handover: ₦${NumberFormat("#,##0").format(handover.amount)} from ${handover.handedOverBy}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'State reason for dispute (e.g. physical shortage or incomplete notes):',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _disputeReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Dispute Reason *',
                    hintText: 'e.g. Physical cash was short by ₦5,000',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
              onPressed: _isProcessing
                  ? null
                  : () async {
                      final reason = _disputeReasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter dispute reason')),
                        );
                        return;
                      }

                      final user = ref.read(authProvider).valueOrNull;
                      if (user == null) return;

                      setDialogState(() => _isProcessing = true);
                      try {
                        final repo = ref.read(cashHandoverRepositoryProvider);
                        await repo.rejectHandover(
                          handoverId: handover.id,
                          receivedBy: user.displayName.isNotEmpty
                              ? user.displayName
                              : 'Treasurer',
                          receivedById: user.uid,
                          reason: reason,
                        );

                        ref.invalidate(cashHandoversStreamProvider);
                        ref.invalidate(pendingCashHandoversStreamProvider);

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Handover voucher disputed')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() => _isProcessing = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Confirm Dispute'),
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
    final handoversAsync = ref.watch(cashHandoversStreamProvider);
    ref.watch(currentOrganizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treasurer Cash Custody & Handovers'),
      ),
      body: handoversAsync.when(
        data: (handovers) {
          final pending = handovers
              .where((h) => h.status == CashHandoverStatus.pending)
              .toList();
          final accepted = handovers
              .where((h) => h.status == CashHandoverStatus.accepted)
              .toList();

          final totalAcceptedAmount =
              accepted.fold<double>(0.0, (sum, h) => sum + h.amount);
          final totalPendingAmount =
              pending.fold<double>(0.0, (sum, h) => sum + h.amount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cash Custody & Liquidity Summary Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade800, Colors.teal.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.account_balance_wallet,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cash Received in Custody',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${accepted.length} Reconciled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(totalAcceptedAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Awaiting Receipt',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currency.format(totalPendingAmount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                              width: 1, height: 28, color: Colors.white24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pending Vouchers',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${pending.length} Voucher${pending.length == 1 ? "" : "s"}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.teal.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shield_outlined, color: Colors.teal),
                          SizedBox(width: 8),
                          Text(
                            'Treasurer Custody Verification',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Whenever the Financial Secretary hands over meeting cash, verify the count physically and confirm the bank deposit account. This completes the dual-control audit trail.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pending Handovers (${pending.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (pending.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No pending cash handovers. All meeting cash is accounted for!'),
                    ),
                  ),
                )
              else
                ...pending.map((h) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                                  fontSize: 18,
                                  color: Colors.teal,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Awaiting Your Receipt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'From: ${h.handedOverBy} • ${dateFormat.format(h.handedOverAt)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if (h.notes != null) ...[
                            const SizedBox(height: 4),
                            Text('Voucher: ${h.notes}', style: const TextStyle(fontSize: 13)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _showDisputeDialog(h),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  child: const Text('Dispute'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAcceptDialog(h),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary(context),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Accept & Deposit'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
              Text(
                'Deposited & Reconciled (${accepted.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              if (accepted.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No completed handovers yet.')),
                  ),
                )
              else
                ...accepted.map((h) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.check, color: Colors.white),
                      ),
                      title: Text(
                        currency.format(h.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Deposited to: ${h.bankName ?? "Bank"} ${h.bankAccountNumber ?? ""}\n'
                        '${dateFormat.format(h.acknowledgedAt ?? h.handedOverAt)}',
                      ),
                      trailing: const Icon(Icons.verified, color: Colors.green),
                    ),
                  );
                }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
