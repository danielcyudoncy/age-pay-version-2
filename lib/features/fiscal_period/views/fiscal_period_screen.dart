import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../models/fiscal_period_model.dart';
import '../controllers/fiscal_period_provider.dart';

class FiscalPeriodScreen extends ConsumerStatefulWidget {
  const FiscalPeriodScreen({super.key});

  @override
  ConsumerState<FiscalPeriodScreen> createState() => _FiscalPeriodScreenState();
}

class _FiscalPeriodScreenState extends ConsumerState<FiscalPeriodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _openingBankController = TextEditingController();
  final _openingCashController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime(2025, 7, 1);
  DateTime _endDate = DateTime(2026, 10, 31);
  bool _isSaving = false;
  FiscalPeriodModel? _editingPeriod;

  @override
  void dispose() {
    _titleController.dispose();
    _openingBalanceController.dispose();
    _openingBankController.dispose();
    _openingCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateForm(FiscalPeriodModel period) {
    setState(() {
      _editingPeriod = period;
      _titleController.text = period.title;
      _openingBalanceController.text = period.openingBalance.toStringAsFixed(0);
      _openingBankController.text = period.openingCashAtBank.toStringAsFixed(0);
      _openingCashController.text = period.openingCashInHand.toStringAsFixed(0);
      _notesController.text = period.notes ?? '';
      _startDate = period.startDate;
      _endDate = period.endDate;
    });
  }

  void _autoSumTotalOpening() {
    final bank = double.tryParse(_openingBankController.text) ?? 0.0;
    final cash = double.tryParse(_openingCashController.text) ?? 0.0;
    if (bank > 0 || cash > 0) {
      _openingBalanceController.text = (bank + cash).toStringAsFixed(0);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _savePeriod() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final total = double.tryParse(_openingBalanceController.text) ?? 0.0;
      final bank = double.tryParse(_openingBankController.text) ?? 0.0;
      final cash = double.tryParse(_openingCashController.text) ?? 0.0;
      final repo = ref.read(fiscalPeriodRepositoryProvider);

      if (_editingPeriod != null) {
        final updated = _editingPeriod!.copyWith(
          title: _titleController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          openingBalance: total,
          openingCashAtBank: bank,
          openingCashInHand: cash,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          updatedAt: DateTime.now(),
        );
        await repo.updateFiscalPeriod(updated);
      } else {
        final newPeriod = FiscalPeriodModel(
          id: '',
          organizationId: user.organizationId,
          branchId: user.branchId,
          title: _titleController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          openingBalance: total,
          openingCashAtBank: bank,
          openingCashInHand: cash,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          createdBy: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createFiscalPeriod(newPeriod);
      }

      ref.invalidate(fiscalPeriodsStreamProvider);
      ref.invalidate(activeFiscalPeriodProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiscal Period & Bal b/f saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving period: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final periodsAsync = ref.watch(fiscalPeriodsStreamProvider);
    final periods = periodsAsync.valueOrNull ?? [];

    if (periods.isNotEmpty && _editingPeriod == null && _titleController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editingPeriod == null) {
          _populateForm(periods.first);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiscal Period & Bal b/f'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (periodsAsync.isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              Card(
                    color: AppTheme.brandGreen.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.brandGreen.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.account_balance, color: AppTheme.brandGreen),
                              SizedBox(width: 8),
                              Text(
                                'Accounting Tenure & Bal b/f',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Define the official tenure dates and opening purse balance (Bal b/f). This is used by the Financial Secretary to calculate the final "Bal at hand / Bank" in the Annual Financial Report.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tenure / Period Title *',
                      hintText: 'e.g. 2025/2026 Executive Tenure',
                      prefixIcon: Icon(Icons.assignment),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date (1/7/25) *',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(dateFormat.format(_startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date (31/10/26) *',
                              prefixIcon: Icon(Icons.event),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(dateFormat.format(_endDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _openingBalanceController,
                    decoration: const InputDecoration(
                      labelText: 'Total Opening Balance / Bal b/f (₦) *',
                      hintText: 'e.g. 805000',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                      helperText: 'Cash + Bank balance brought forward into this tenure',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Opening balance is required' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _openingBankController,
                          decoration: const InputDecoration(
                            labelText: 'In Bank (₦)',
                            hintText: 'e.g. 750000',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _autoSumTotalOpening(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _openingCashController,
                          decoration: const InputDecoration(
                            labelText: 'Cash in Hand (₦)',
                            hintText: 'e.g. 55000',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _autoSumTotalOpening(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Explanatory Notes (Optional)',
                      hintText: 'e.g. Bal b/f audited and handed over by outgoing executives',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _savePeriod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Fiscal Period & Bal b/f',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),

                  if (periods.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Saved Tenures / Periods',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...periods.map((p) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${dateFormat.format(p.startDate)} - ${dateFormat.format(p.endDate)}\n'
                            'Bal b/f: ${currency.format(p.openingBalance)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _populateForm(p),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
  }
}
