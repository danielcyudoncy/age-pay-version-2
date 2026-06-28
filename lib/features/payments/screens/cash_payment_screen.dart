import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/features/payments/providers/offline_payment_provider.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';

class CashPaymentScreen extends ConsumerStatefulWidget {
  final String recordedBy;

  const CashPaymentScreen({super.key, required this.recordedBy});

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
  void dispose() {
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
    final searchAsync = ref.watch(memberSearchProvider(_searchQuery));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search member by name, email or phone',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: searchAsync.when(
            data: (members) {
              if (_searchQuery.isEmpty) {
                return const Center(
                  child: Text('Type at least 1 character to search'),
                );
              }
              if (members.isEmpty) {
                return const Center(child: Text('No members found'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(member.fullName),
                      subtitle: Text(member.email),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

    return Column(
      children: [
        if (state.error != null)
          Container(
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
        Container(
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
                    ),
                    Text(_selectedMember!.email),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select obligations to settle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: obligationsAsync.when(
            data: (obligations) {
              if (obligations.isEmpty) {
                return const Center(
                  child: Text('No outstanding obligations for this member'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: obligations.length,
                itemBuilder: (context, index) {
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    hintText: 'Add any notes about this payment',
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
                    Text(
                      currency.format(
                        double.tryParse(_amountController.text) ?? 0.0,
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isLoading || selectedObligations.isEmpty
                      ? null
                      : _recordPayment,
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
                    state.isLoading ? 'Recording...' : 'Record Payment',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(NumberFormat currency, OfflinePaymentState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Recorded'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Cash Payment Recorded!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (state.receiptNumber != null)
                Text(
                  'Receipt: ${state.receiptNumber}',
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 8),
              if (state.paymentId != null)
                Text(
                  'Payment ID: ${state.paymentId}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  ref.read(offlinePaymentProvider.notifier).reset();
                  ref.read(selectedObligationsProvider.notifier).clear();
                  setState(() {
                    _selectedMember = null;
                    _amountController.clear();
                    _notesController.clear();
                  });
                },
                child: const Text('Record Another'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final selected = ref.read(selectedObligationsProvider);
    if (amount <= 0 || selected.isEmpty) return;

    await ref
        .read(offlinePaymentProvider.notifier)
        .recordCashPayment(
          memberId: _selectedMember!.userId,
          obligationIds: selected.map((o) => o.id).toList(),
          amount: amount,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          recordedBy: widget.recordedBy,
        );
  }
}
