// features/payments/views/make_payment_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/features/payments/controllers/payment_provider.dart';
import 'package:cls/features/payments/controllers/offline_payment_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymentOptionMode { specific, allOutstanding, custom, bankTransfer }

class MakePaymentScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String memberEmail;
  final List<ObligationModel>? obligations;

  const MakePaymentScreen({
    super.key,
    required this.memberId,
    required this.memberEmail,
    this.obligations,
  });

  @override
  ConsumerState<MakePaymentScreen> createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends ConsumerState<MakePaymentScreen> {
  final Set<String> _selectedObligationIds = {};
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _showWebView = false;
  PaymentOptionMode _paymentMode = PaymentOptionMode.specific;
  File? _pickedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  List<ObligationModel> _cachedObligations = [];

  @override
  void initState() {
    super.initState();
  }

  List<ObligationModel> _getFilteredObligations(List<ObligationModel> items) {
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
      case PaymentOptionMode.bankTransfer:
        return items
            .where((o) => _selectedObligationIds.contains(o.id))
            .toList();
      case PaymentOptionMode.allOutstanding:
        return items;
      case PaymentOptionMode.custom:
        return items
            .where((o) => _selectedObligationIds.contains(o.id))
            .toList();
    }
  }

  double _getTotalToPay(List<ObligationModel> allItems) {
    final customAmount = double.tryParse(_customAmountController.text) ?? 0.0;
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
      case PaymentOptionMode.allOutstanding:
        return allItems
            .where((o) => _selectedObligationIds.contains(o.id))
            .fold(0.0, (sum, o) => sum + o.outstandingBalance);
      case PaymentOptionMode.custom:
      case PaymentOptionMode.bankTransfer:
        return customAmount > 0 ? customAmount : 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentFlowProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    if (paymentState.isSuccess) {
      return _buildSuccessView(currency, paymentState);
    }

    if (_showWebView && paymentState.authorizationUrl != null) {
      return _buildWebView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Make Payment'), centerTitle: true),
      body: _buildContent(currency, paymentState),
    );
  }

  Widget _buildContent(NumberFormat currency, PaymentFlowState paymentState) {
    final offlineState = ref.watch(offlinePaymentProvider);

    if (offlineState.isSuccess &&
        _paymentMode == PaymentOptionMode.bankTransfer) {
      return _buildTransferPendingView(offlineState);
    }

    if (paymentState.isSuccess) {
      return _buildSuccessView(currency, paymentState);
    }

    if (_showWebView && paymentState.authorizationUrl != null) {
      return _buildWebView();
    }

    if (widget.obligations != null) {
      final items = widget.obligations!;
      _cachedObligations = items;
      return _buildObligationSelector(
        currency,
        paymentState,
        obligations: items,
      );
    }

    return _buildStreamedObligations(currency, paymentState);
  }

  Widget _buildSuccessView(NumberFormat currency, PaymentFlowState state) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Successful')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
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
                  ref.read(paymentFlowProvider.notifier).reset();
                  ref.read(offlinePaymentProvider.notifier).reset();
                  ref.read(selectedObligationsProvider.notifier).clear();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferPendingView(OfflinePaymentState state) {
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
                    _bankNameController.clear();
                    _notesController.clear();
                    _customAmountController.clear();
                    _pickedImage = null;
                    _uploadedImageUrl = null;
                    _isUploading = false;
                    _selectedObligationIds.clear();
                    _paymentMode = PaymentOptionMode.specific;
                  });
                },
                child: const Text('Submit Another'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(offlinePaymentProvider.notifier).reset();
                  ref.read(selectedObligationsProvider.notifier).clear();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complete Payment')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.open_in_browser, size: 64, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  "Complete your payment in the new tab, then come back and tap \"I've Paid\".",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(ref.read(paymentFlowProvider).authorizationUrl!),
                    webOnlyWindowName: '_blank',
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Payment Page'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _showWebView = false);
                    final state = ref.read(paymentFlowProvider);
                    if (state.reference != null) {
                      _verifyPayment(state.reference!, _cachedObligations);
                    }
                  },
                  child: const Text("I've Paid"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.contains('success') ||
                request.url.contains('callback')) {
              setState(() => _showWebView = false);
              final state = ref.read(paymentFlowProvider);
              if (state.reference != null) {
                _verifyPayment(state.reference!, _cachedObligations);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(ref.read(paymentFlowProvider).authorizationUrl!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _showWebView = false);
              final state = ref.read(paymentFlowProvider);
              if (state.reference != null) {
                _verifyPayment(state.reference!, _cachedObligations);
              }
            },
            child: const Text('I\'ve Paid'),
          ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    );
  }

  Widget _buildPaymentModeCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildStreamedObligations(
    NumberFormat currency,
    PaymentFlowState paymentState,
  ) {
    final obligationsAsync = ref.watch(
      memberActiveObligationsProvider(widget.memberId),
    );

    return obligationsAsync.when(
      data: (obligations) {
        _cachedObligations = obligations;
        if (obligations.isEmpty) {
          return _buildEmptyState('No outstanding obligations');
        }
        return _buildObligationSelector(
          currency,
          paymentState,
          obligations: obligations,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading obligations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(
                    memberActiveObligationsProvider(widget.memberId),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You have no pending payments at this time.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _setPaymentMode(PaymentOptionMode mode, List<ObligationModel> items) {
    setState(() {
      _paymentMode = mode;
      if (mode == PaymentOptionMode.allOutstanding) {
        _selectedObligationIds.addAll(
          items
              .map((o) => o.id)
              .where((id) => !_selectedObligationIds.contains(id)),
        );
      }
      if (mode != PaymentOptionMode.bankTransfer) {
        _uploadedImageUrl = null;
        _pickedImage = null;
        _isUploading = false;
        _bankNameController.clear();
      }
    });
  }

  Widget _paymentModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildObligationSelector(
    NumberFormat currency,
    PaymentFlowState paymentState, {
    List<ObligationModel>? obligations,
  }) {
    final items = obligations ?? [];

    return Column(
      children: [
        if (paymentState.error != null)
          Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    paymentState.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      ref.read(paymentFlowProvider.notifier).clearError(),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Options',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _paymentModeChip(
                      label: 'Specific',
                      selected: _paymentMode == PaymentOptionMode.specific,
                      onTap: () =>
                          _setPaymentMode(PaymentOptionMode.specific, items),
                    ),
                    _paymentModeChip(
                      label: 'All Outstanding',
                      selected:
                          _paymentMode == PaymentOptionMode.allOutstanding,
                      onTap: () => _setPaymentMode(
                        PaymentOptionMode.allOutstanding,
                        items,
                      ),
                    ),
                    _paymentModeChip(
                      label: 'Custom Amount',
                      selected: _paymentMode == PaymentOptionMode.custom,
                      onTap: () =>
                          _setPaymentMode(PaymentOptionMode.custom, items),
                    ),
                    _paymentModeChip(
                      label: 'Bank Transfer',
                      selected: _paymentMode == PaymentOptionMode.bankTransfer,
                      onTap: () => _setPaymentMode(
                        PaymentOptionMode.bankTransfer,
                        items,
                      ),
                    ),
                  ],
                ),
                if (_paymentMode != PaymentOptionMode.bankTransfer) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _paymentModeChip(
                        label: 'Paystack',
                        selected: paymentState.selectedProvider ==
                            PaymentProvider.paystack,
                        onTap: () {
                          ref
                              .read(paymentFlowProvider.notifier)
                              .selectProvider(PaymentProvider.paystack);
                          setState(() {});
                        },
                      ),
                      _paymentModeChip(
                        label: 'Flutterwave',
                        selected: paymentState.selectedProvider ==
                            PaymentProvider.flutterwave,
                        onTap: () {
                          ref
                              .read(paymentFlowProvider.notifier)
                              .selectProvider(PaymentProvider.flutterwave);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (_paymentMode == PaymentOptionMode.custom) ...[
                  _buildPaymentModeCard(
                    child: TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Custom Amount',
                        hintText: 'Enter any amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixText: '₦ ',
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ),
                ],
                if (_paymentMode == PaymentOptionMode.bankTransfer) ...[
                  _buildPaymentModeCard(
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Upload your bank transfer receipt and enter the details below.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _customAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Transfer Amount',
                            hintText: 'Enter amount paid',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixText: '₦ ',
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _buildEmptyState('No outstanding obligations')
                else
                  Column(
                    children: items.map((obligation) {
                      final isSelected = _selectedObligationIds.contains(
                        obligation.id,
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
                            setState(() {
                              if (value == true) {
                                _selectedObligationIds.add(obligation.id);
                              } else {
                                _selectedObligationIds.remove(obligation.id);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
              ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _paymentMode == PaymentOptionMode.custom ||
                              _paymentMode == PaymentOptionMode.bankTransfer
                          ? 'Custom Amount:'
                          : 'Total to Pay:',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      currency.format(_getTotalToPay(items)),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isPayButtonEnabled(items, paymentState)
                      ? () {
                          if (_paymentMode == PaymentOptionMode.bankTransfer) {
                            _submitTransfer();
                          } else {
                            _initiatePayment(items);
                          }
                        }
                      : null,
                  icon: _getButtonIcon(paymentState),
                  label: Text(_getButtonLabel(paymentState)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isPayButtonEnabled(
    List<ObligationModel> items,
    PaymentFlowState state,
  ) {
    final offlineState = ref.read(offlinePaymentProvider);
    if (state.isInitializing || offlineState.isLoading) return false;
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
        return _selectedObligationIds.isNotEmpty;
      case PaymentOptionMode.allOutstanding:
        return items.isNotEmpty;
      case PaymentOptionMode.custom:
        final customAmount =
            double.tryParse(_customAmountController.text) ?? 0.0;
        return customAmount > 0 && _selectedObligationIds.isNotEmpty;
      case PaymentOptionMode.bankTransfer:
        final amount = double.tryParse(_customAmountController.text) ?? 0.0;
        return amount > 0 &&
            _selectedObligationIds.isNotEmpty &&
            _uploadedImageUrl != null &&
            _bankNameController.text.isNotEmpty;
    }
  }

  Widget _getButtonIcon(PaymentFlowState paymentState) {
    final offlineState = ref.read(offlinePaymentProvider);
    if (_paymentMode == PaymentOptionMode.bankTransfer) {
      if (offlineState.isLoading) {
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      }
      return const Icon(Icons.send);
    }
    if (paymentState.isInitializing) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return const Icon(Icons.payment);
  }

  String _getButtonLabel(PaymentFlowState paymentState) {
    final offlineState = ref.read(offlinePaymentProvider);
    if (_paymentMode == PaymentOptionMode.bankTransfer) {
      return offlineState.isLoading ? 'Submitting...' : 'Submit Transfer';
    }
    if (paymentState.isInitializing) {
      return 'Initializing...';
    }
    final provider = paymentState.selectedProvider;
    switch (provider) {
      case PaymentProvider.paystack:
        return 'Pay with Paystack';
      case PaymentProvider.flutterwave:
        return 'Pay with Flutterwave';
    }
  }

  Future<void> _initiatePayment(List<ObligationModel> allItems) async {
    final obligationsToPay = _getFilteredObligations(allItems);
    final amount = _getTotalToPay(allItems);

    await ref
        .read(paymentFlowProvider.notifier)
        .initializePayment(
          email: widget.memberEmail,
          amountNaira: amount,
          memberId: widget.memberId,
          obligations: obligationsToPay,
        );

    final state = ref.read(paymentFlowProvider);
    if (state.authorizationUrl != null && state.error == null) {
      setState(() => _showWebView = true);
    }
  }

  Future<void> _verifyPayment(
    String reference,
    List<ObligationModel> allItems,
  ) async {
    final obligationsToPay = _getFilteredObligations(allItems);
    final amount = _getTotalToPay(allItems);

    await ref
        .read(paymentFlowProvider.notifier)
        .verifyPayment(
          reference: reference,
          memberId: widget.memberId,
          obligationIds: obligationsToPay.map((o) => o.id).toList(),
          amountPaid: amount,
        );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final fileName =
          'transfer_${widget.memberId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(
        'receipts/${widget.memberId}/$fileName',
      );

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes);
      } else {
        setState(() {
          _pickedImage = File(picked.path);
        });
        await ref.putFile(_pickedImage!);
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _submitTransfer() async {
    final amount = double.tryParse(_customAmountController.text) ?? 0.0;
    final selectedIds = _selectedObligationIds.toList();
    if (amount <= 0 || selectedIds.isEmpty || _uploadedImageUrl == null) return;

    await ref
        .read(offlinePaymentProvider.notifier)
        .submitBankTransfer(
          memberId: widget.memberId,
          obligationIds: selectedIds,
          amount: amount,
          transferReference: 'TRF-${DateTime.now().millisecondsSinceEpoch}',
          bankName: _bankNameController.text,
          receiptUrl: _uploadedImageUrl!,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _bankNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
