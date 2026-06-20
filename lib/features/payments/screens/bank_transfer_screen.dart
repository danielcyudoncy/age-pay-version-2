import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/providers/offline_payment_provider.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';

class BankTransferScreen extends ConsumerStatefulWidget {
  final String memberId;

  const BankTransferScreen({
    super.key,
    required this.memberId,
  });

  @override
  ConsumerState<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends ConsumerState<BankTransferScreen> {
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _transferDate;
  File? _pickedImage;
  bool _isUploading = false;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _referenceController.dispose();
    _bankNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _pickedImage = File(picked.path);
      _isUploading = true;
    });

    try {
      final fileName =
          'transfer_${widget.memberId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref('receipts/${widget.memberId}/$fileName');
      await ref.putFile(_pickedImage!);
      final url = await ref.getDownloadURL();

      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _transferDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final state = ref.watch(offlinePaymentProvider);
    final selectedObligations = ref.watch(selectedObligationsProvider);

    if (state.isSuccess) {
      return _buildPendingView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Bank Transfer'),
        centerTitle: true,
      ),
      body: Column(
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Select obligations to settle',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildObligationsList(currency),
                const SizedBox(height: 24),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Transfer Amount (₦)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixText: '₦ ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: 'Transfer Reference Number',
                    hintText: 'e.g. TRX123456789',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: 'Bank Name',
                    hintText: 'e.g. First Bank of Nigeria',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Transfer Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _transferDate != null
                          ? DateFormat('dd MMM yyyy').format(_transferDate!)
                          : 'Select date',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickImage,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(
                    _uploadedImageUrl != null
                        ? 'Receipt Uploaded'
                        : 'Upload Transfer Receipt',
                  ),
                ),
                if (_uploadedImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Receipt uploaded successfully',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: state.isLoading ||
                            selectedObligations.isEmpty ||
                            _uploadedImageUrl == null
                        ? null
                        : _submitTransfer,
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      state.isLoading ? 'Submitting...' : 'Submit Transfer',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObligationsList(NumberFormat currency) {
    final obligationsAsync = ref.watch(
      memberActiveObligationsProvider(widget.memberId),
    );

    return obligationsAsync.when(
      data: (obligations) {
        if (obligations.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No outstanding obligations'),
            ),
          );
        }
        final selectedObligations = ref.watch(selectedObligationsProvider);
        return Column(
          children: obligations.map((obligation) {
            final isSelected =
                selectedObligations.any((o) => o.id == obligation.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
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
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildPendingView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Submitted'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pending, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Transfer Submitted!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your payment is pending verification by the treasurer. You will be notified once it is approved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  ref.read(offlinePaymentProvider.notifier).reset();
                  ref.read(selectedObligationsProvider.notifier).clear();
                  setState(() {
                    _referenceController.clear();
                    _bankNameController.clear();
                    _amountController.clear();
                    _notesController.clear();
                    _transferDate = null;
                    _pickedImage = null;
                    _uploadedImageUrl = null;
                  });
                },
                child: const Text('Submit Another'),
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

  Future<void> _submitTransfer() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final selected = ref.read(selectedObligationsProvider);
    if (amount <= 0 || selected.isEmpty || _uploadedImageUrl == null) return;

    await ref.read(offlinePaymentProvider.notifier).submitBankTransfer(
      memberId: widget.memberId,
      obligationIds: selected.map((o) => o.id).toList(),
      amount: amount,
      transferReference: _referenceController.text,
      bankName: _bankNameController.text,
      receiptUrl: _uploadedImageUrl!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );
  }
}
