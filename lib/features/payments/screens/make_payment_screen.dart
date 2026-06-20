// features/payments/screens/make_payment_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/obligation_model.dart';
import 'package:cls/features/obligations/providers/obligation_provider.dart';
import 'package:cls/features/payments/providers/payment_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymentOptionMode { specific, allOutstanding, custom }

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
  bool _showWebView = false;
  PaymentOptionMode _paymentMode = PaymentOptionMode.specific;
  
  List<ObligationModel> _cachedObligations = [];

  @override
  void initState() {
    super.initState();
  }

  List<ObligationModel> _getFilteredObligations(List<ObligationModel> items) {
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
        return items.where((o) => _selectedObligationIds.contains(o.id)).toList();
      case PaymentOptionMode.allOutstanding:
        return items;
      case PaymentOptionMode.custom:
        return items.where((o) => _selectedObligationIds.contains(o.id)).toList();
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
                  onPressed: () =>
                      launchUrl(Uri.parse(ref.read(paymentFlowProvider).authorizationUrl!), webOnlyWindowName: '_blank'),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Options',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<PaymentOptionMode>(
                segments: const [
                  ButtonSegment(
                    value: PaymentOptionMode.specific,
                    label: Text('Specific'),
                    icon: Icon(Icons.checklist, size: 16),
                  ),
                  ButtonSegment(
                    value: PaymentOptionMode.allOutstanding,
                    label: Text('All Outstanding'),
                    icon: Icon(Icons.select_all, size: 16),
                  ),
                  ButtonSegment(
                    value: PaymentOptionMode.custom,
                    label: Text('Custom Amount'),
                    icon: Icon(Icons.edit, size: 16),
                  ),
                ],
                selected: {_paymentMode},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _paymentMode = newSelection.first;
                    if (_paymentMode == PaymentOptionMode.allOutstanding) {
                      _selectedObligationIds.addAll(
                        items
                            .map((o) => o.id)
                            .where(
                              (id) => !_selectedObligationIds.contains(id),
                            ),
                      );
                    }
                  });
                },
              ),
              if (_paymentMode == PaymentOptionMode.custom) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Custom Amount (₦)',
                    hintText: 'Enter any amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixText: '₦ ',
                  ),
                  onChanged: (_) {
                    setState(() {
                      // Recalculate total when amount changes
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState('No outstanding obligations')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final obligation = items[index];
                    final isSelected =
                        _selectedObligationIds.contains(obligation.id);

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
                          backgroundColor: obligation.status == ObligationStatus.unpaid
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
                  },
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _paymentMode == PaymentOptionMode.custom
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
                      ? () => _initiatePayment(items)
                      : null,
                  icon: paymentState.isInitializing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    paymentState.isInitializing
                        ? 'Initializing...'
                        : 'Pay with Paystack',
                  ),
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
    if (state.isInitializing) return false;
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
        return _selectedObligationIds.isNotEmpty;
      case PaymentOptionMode.allOutstanding:
        return items.isNotEmpty;
      case PaymentOptionMode.custom:
        final customAmount = double.tryParse(_customAmountController.text) ?? 0.0;
        // Custom payments still require obligation selection for proper allocation
        return customAmount > 0 && _selectedObligationIds.isNotEmpty;
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

  Future<void> _verifyPayment(String reference, List<ObligationModel> allItems) async {
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

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }
}