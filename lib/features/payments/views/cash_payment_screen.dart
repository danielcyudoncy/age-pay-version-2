import 'package:cls/core/theme/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/payments/controllers/offline_payment_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show membersStreamProvider;
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/settings/widgets/read_only_license_dialog.dart';
import 'package:cls/features/settings/widgets/license_status_banner.dart';

class CashPaymentScreen extends ConsumerStatefulWidget {
  final String recordedBy;
  final MemberModel? initialMember;

  const CashPaymentScreen({
    super.key,
    required this.recordedBy,
    this.initialMember,
  });

  @override
  ConsumerState<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends ConsumerState<CashPaymentScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  MemberModel? _selectedMember;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.initialMember;
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _searchController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
    });
  }

  double get _totalFromObligations {
    final selected = ref.watch(selectedObligationsProvider);
    return selected.fold(0.0, (sum, o) => sum + o.outstandingBalance);
  }

  void _updateAmountFromSelection() {
    final total = _totalFromObligations;
    if (total > 0) {
      _amountController.text = total.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final state = ref.watch(offlinePaymentProvider);
    final selectedObligations = ref.watch(selectedObligationsProvider);

    if (state.isSuccess && state.receiptNumber != null) {
      return _buildSuccessView(currency, state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Cash Payment'),
        centerTitle: true,
      ),
      body: _selectedMember == null
          ? _buildMemberSearch(currency)
          : _buildPaymentForm(currency, state, selectedObligations),
    );
  }

  Widget _buildMemberSearch(NumberFormat currency) {
    final membersAsync = ref.watch(membersStreamProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search member by name, email or phone',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Select a member to view dues and record cash payment',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: membersAsync.when(
            data: (members) {
              final q = _searchQuery.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? members
                  : members.where((m) {
                      return m.fullName.toLowerCase().contains(q) ||
                          m.email.toLowerCase().contains(q) ||
                          m.phoneNumber.toLowerCase().contains(q);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No registered members found'
                            : 'No members matching "$_searchQuery"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.statusBg(context, Colors.teal),
                        child: Text(
                          member.fullName.isNotEmpty
                              ? member.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: AppTheme.statusColor(context, Colors.teal),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        member.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        member.phoneNumber.isNotEmpty
                            ? member.phoneNumber
                            : (member.email.isNotEmpty
                                ? member.email
                                : 'Registered Member'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Select',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMember = member;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        ref.read(selectedObligationsProvider.notifier).clear();
                        _amountController.clear();
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(
    NumberFormat currency,
    OfflinePaymentState state,
    List<ObligationModel> selectedObligations,
  ) {
    final obligationsAsync = ref.watch(
      memberActiveObligationsProvider(_selectedMember!.id),
    );
    final org = ref.watch(currentOrganizationProvider).valueOrNull;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (org != null)
          SliverToBoxAdapter(
            child: LicenseStatusBanner(org: org, isExecutive: true),
          ),
        if (state.error != null)
          SliverToBoxAdapter(
            child: Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        ref.read(offlinePaymentProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMember!.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _selectedMember!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMember = null;
                      _amountController.clear();
                      _notesController.clear();
                    });
                    ref.read(selectedObligationsProvider.notifier).clear();
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select obligations to settle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        obligationsAsync.when(
          data: (obligations) {
            if (obligations.isEmpty) {
              return SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'All current obligations settled! 🎉',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This member has no unpaid dues. You can record an upfront payment or wallet deposit below.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final obligation = obligations[index];
                    final isSelected = selectedObligations.any(
                      (o) => o.id == obligation.id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CheckboxListTile(
                        title: Text(obligation.title),
                        subtitle: Text(
                          'Outstanding: ${currency.format(obligation.outstandingBalance)}',
                        ),
                        secondary: Chip(
                          label: Text(
                            obligation.status == ObligationStatus.unpaid
                                ? 'Unpaid'
                                : 'Partial',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor:
                              obligation.status == ObligationStatus.unpaid
                              ? Colors.red
                              : Colors.orange,
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          ref
                              .read(selectedObligationsProvider.notifier)
                              .toggle(obligation);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _updateAmountFromSelection();
                          });
                        },
                      ),
                    );
                  },
                  childCount: obligations.length,
                ),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selectedObligations.isNotEmpty
                          ? Colors.teal.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedObligations.isNotEmpty
                              ? Icons.checklist
                              : Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: selectedObligations.isNotEmpty
                              ? Colors.teal
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedObligations.isNotEmpty
                                ? 'Settling ${selectedObligations.length} selected obligation${selectedObligations.length > 1 ? 's' : ''}'
                                : 'Upfront / Advance payment (wallet credit)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selectedObligations.isNotEmpty
                                  ? Colors.teal.shade800
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (₦)',
                      hintText: 'Enter payment amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixText: '₦ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: selectedObligations.isEmpty
                          ? 'e.g. Upfront payment for upcoming dues'
                          : 'Add any notes about this payment',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          currency.format(
                            double.tryParse(_amountController.text) ?? 0.0,
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: !state.isLoading &&
                            (double.tryParse(_amountController.text.trim()) ??
                                    0.0) >
                                0
                        ? _recordPayment
                        : null,
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payments),
                    label: Text(
                      state.isLoading
                          ? 'Recording...'
                          : (selectedObligations.isNotEmpty
                              ? 'Record Payment (${selectedObligations.length} due${selectedObligations.length > 1 ? 's' : ''})'
                              : 'Record Upfront / Advance Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + 24,
          ),
        ),
      ],
    );
  }

  String _formatPaymentId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
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

  Widget _buildSuccessView(NumberFormat currency, OfflinePaymentState state) {
    final paymentRef = _formatPaymentId(state.paymentId);
    final amountPaid = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final memberName = _selectedMember?.fullName ?? 'Registered Member';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Confirmation'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 52,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cash Payment Recorded!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Official cash receipt has been generated',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.cardBorder(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (amountPaid > 0) ...[
                        Text(
                          currency.format(amountPaid),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          memberName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const Divider(height: 28),
                      ],
                      if (state.receiptNumber != null) ...[
                        _buildReceiptRow(
                          'Receipt No:',
                          state.receiptNumber!,
                          isBold: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildReceiptRow('Payment ID:', paymentRef),
                      const SizedBox(height: 10),
                      _buildReceiptRow('Payment Method:', 'Cash in Hand'),
                      const SizedBox(height: 10),
                      _buildReceiptRow(
                        'Status:',
                        'Approved & Recorded',
                        valueColor: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(offlinePaymentProvider.notifier).reset();
                    ref.read(selectedObligationsProvider.notifier).clear();
                    setState(() {
                      _selectedMember = null;
                      _amountController.clear();
                      _notesController.clear();
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Record Another Payment'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(offlinePaymentProvider.notifier).reset();
                    ref.read(selectedObligationsProvider.notifier).clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _recordPayment() async {
    final org = ref.read(currentOrganizationProvider).valueOrNull;
    if (org != null && org.isReadOnly) {
      if (mounted) {
        ReadOnlyLicenseDialog.show(context, actionName: 'recording cash payments');
      }
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    final selected = ref.read(selectedObligationsProvider);
    final isAdvance = selected.isEmpty;
    final userNote = _notesController.text.trim();
    final noteToSave = userNote.isNotEmpty
        ? userNote
        : (isAdvance ? 'Upfront / Advance Cash Payment' : null);

    final memberUserId = _selectedMember!.userId.isNotEmpty
        ? _selectedMember!.userId
        : _selectedMember!.id;

    await ref
        .read(offlinePaymentProvider.notifier)
        .recordCashPayment(
          memberId: memberUserId,
          obligationIds: selected.map((o) => o.id).toList(),
          amount: amount,
          notes: noteToSave,
          recordedBy: widget.recordedBy,
        );
  }
}
