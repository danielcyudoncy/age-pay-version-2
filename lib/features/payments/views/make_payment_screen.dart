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
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymentOptionMode { specific, allOutstanding, custom, bankTransfer }

class MakePaymentScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String? memberEmail;
  final List<ObligationModel>? obligations;

  const MakePaymentScreen({
    super.key,
    required this.memberId,
    this.memberEmail,
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

  PaymentOptionMode _paymentMode = PaymentOptionMode.bankTransfer;
  File? _pickedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _showWebView = false;
  WebViewController? _webViewController;

  List<ObligationModel> _cachedObligations = [];
  String? _cachedOrgName;

  @override
  void initState() {
    super.initState();
    _fetchOrgName();
    // Clean up previous flow state on entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentFlowProvider.notifier).reset();
      ref.read(offlinePaymentProvider.notifier).reset();
    });
  }

  Future<void> _fetchOrgName() async {
    try {
      final orgId = await ref.read(organizationIdProvider.future);
      if (orgId.isNotEmpty) {
        final org = await ref
            .read(organizationRepositoryProvider)
            .getOrganizationById(orgId);
        if (mounted && org != null && org.name.isNotEmpty) {
          setState(() => _cachedOrgName = org.name);
        }
      }
    } catch (_) {}
  }

  List<ObligationModel> _getFilteredObligations(List<ObligationModel> items) {
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
      case PaymentOptionMode.bankTransfer:
      case PaymentOptionMode.custom:
        return items
            .where((o) => _selectedObligationIds.contains(o.id))
            .toList();
      case PaymentOptionMode.allOutstanding:
        return items;
    }
  }

  double _getTotalToPay(List<ObligationModel> allItems) {
    final customAmount = double.tryParse(_customAmountController.text) ?? 0.0;
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
        return allItems
            .where((o) => _selectedObligationIds.contains(o.id))
            .fold(0.0, (sum, o) => sum + o.outstandingBalance);
      case PaymentOptionMode.allOutstanding:
        return allItems.fold(0.0, (sum, o) => sum + o.outstandingBalance);
      case PaymentOptionMode.custom:
      case PaymentOptionMode.bankTransfer:
        return customAmount > 0 ? customAmount : 0.0;
    }
  }

  void _setPaymentMode(PaymentOptionMode mode, List<ObligationModel> items) {
    setState(() {
      _paymentMode = mode;
      if (mode == PaymentOptionMode.allOutstanding) {
        _selectedObligationIds.clear();
        _selectedObligationIds.addAll(items.map((o) => o.id));
      } else if (mode == PaymentOptionMode.specific) {
        if (_selectedObligationIds.isEmpty && items.isNotEmpty) {
          _selectedObligationIds.add(items.first.id);
        }
      } else if (mode == PaymentOptionMode.custom ||
          mode == PaymentOptionMode.bankTransfer) {
        if (_selectedObligationIds.isEmpty && items.isNotEmpty) {
          _selectedObligationIds.add(items.first.id);
        }
        final total = items
            .where((o) => _selectedObligationIds.contains(o.id))
            .fold(0.0, (sum, o) => sum + o.outstandingBalance);
        if (_customAmountController.text.isEmpty && total > 0) {
          _customAmountController.text = total.toStringAsFixed(0);
        }
      }

      if (mode != PaymentOptionMode.bankTransfer) {
        _uploadedImageUrl = null;
        _pickedImage = null;
        _isUploading = false;
        _bankNameController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentFlowProvider);
    final offlineState = ref.watch(offlinePaymentProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    // 1. Online Payment Success View
    if (paymentState.isSuccess) {
      return _buildSuccessView(currency, paymentState);
    }

    // 2. Bank Transfer Submitted View
    if (offlineState.isSuccess && _paymentMode == PaymentOptionMode.bankTransfer) {
      return _buildTransferPendingView(offlineState);
    }

    // 3. Online Payment Verification Loading View
    if (paymentState.isVerifying) {
      return _buildVerifyingView(paymentState);
    }

    // 4. Online Payment Gateway WebView
    if (_showWebView && paymentState.authorizationUrl != null) {
      return _buildWebView();
    }

    // 5. Main Form
    return Scaffold(
      appBar: AppBar(title: const Text('Make Payment'), centerTitle: true),
      body: _buildContent(currency, paymentState, offlineState),
    );
  }

  Widget _buildContent(
    NumberFormat currency,
    PaymentFlowState paymentState,
    OfflinePaymentState offlineState,
  ) {
    if (widget.obligations != null) {
      final items = widget.obligations!;
      _cachedObligations = items;
      return _buildObligationSelector(
        currency,
        paymentState,
        offlineState,
        obligations: items,
      );
    }

    return _buildStreamedObligations(currency, paymentState, offlineState);
  }

  Widget _buildVerifyingView(PaymentFlowState state) {
    final providerName = state.selectedProvider == PaymentProvider.paystack
        ? 'Paystack'
        : 'Flutterwave';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifying Payment'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 32),
              const Text(
                'Confirming Transaction...',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please wait while we verify your payment with $providerName. Do not close or navigate away from the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(NumberFormat currency, PaymentFlowState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
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
                'Payment Successful!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (state.receiptNumber != null)
                Text(
                  'Receipt: ${state.receiptNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Transfer Submitted!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your payment proof has been submitted and is pending verification by the financial secretary / treasurer. You will receive an update once approved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4),
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

  void _initWebViewController(String url) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = request.url.toLowerCase();
            if (uri.contains('success') ||
                uri.contains('callback') ||
                uri.contains('close') ||
                uri.contains('approved')) {
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
      ..loadRequest(Uri.parse(url));
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
                  "Complete your payment in the browser tab, then return and tap \"I've Paid\".",
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

    if (_webViewController == null &&
        ref.read(paymentFlowProvider).authorizationUrl != null) {
      _initWebViewController(ref.read(paymentFlowProvider).authorizationUrl!);
    }

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
            child: const Text("I've Paid"),
          ),
        ],
      ),
      body: _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildStreamedObligations(
    NumberFormat currency,
    PaymentFlowState paymentState,
    OfflinePaymentState offlineState,
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
          offlineState,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildObligationSelector(
    NumberFormat currency,
    PaymentFlowState paymentState,
    OfflinePaymentState offlineState, {
    List<ObligationModel>? obligations,
  }) {
    final items = obligations ?? [];
    final activeError = paymentState.error ?? offlineState.error;

    return Column(
      children: [
        if (activeError != null)
          Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeError,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () {
                    ref.read(paymentFlowProvider.notifier).clearError();
                    ref.read(offlinePaymentProvider.notifier).clearError();
                  },
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
                // 1. Payment Scope Selector
                Text(
                  'Select Payment Type',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 16),

                // 2. Online Payment Gateway selector (if not Bank Transfer)
                if (_paymentMode != PaymentOptionMode.bankTransfer) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Online Gateway',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: paymentState.selectedProvider ==
                                      PaymentProvider.paystack
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: paymentState.selectedProvider ==
                                      PaymentProvider.paystack
                                  ? 2.0
                                  : 1.0,
                            ),
                            backgroundColor: paymentState.selectedProvider ==
                                    PaymentProvider.paystack
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.4)
                                : null,
                          ),
                          onPressed: () {
                            ref
                                .read(paymentFlowProvider.notifier)
                                .selectProvider(PaymentProvider.paystack);
                            _showOnlineGatewayComingSoonDialog('Paystack');
                          },
                          icon: const Icon(Icons.credit_card, size: 18),
                          label: const Text('Paystack'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: paymentState.selectedProvider ==
                                      PaymentProvider.flutterwave
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: paymentState.selectedProvider ==
                                      PaymentProvider.flutterwave
                                  ? 2.0
                                  : 1.0,
                            ),
                            backgroundColor: paymentState.selectedProvider ==
                                    PaymentProvider.flutterwave
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.4)
                                : null,
                          ),
                          onPressed: () {
                            ref
                                .read(paymentFlowProvider.notifier)
                                .selectProvider(PaymentProvider.flutterwave);
                            _showOnlineGatewayComingSoonDialog('Flutterwave');
                          },
                          icon: const Icon(Icons.account_balance_wallet, size: 18),
                          label: const Text('Flutterwave'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Custom Amount input
                if (_paymentMode == PaymentOptionMode.custom) ...[
                  _buildPaymentModeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Specify Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount to Pay',
                            hintText: 'Enter amount in Naira',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixText: '₦ ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Bank Transfer Form
                if (_paymentMode == PaymentOptionMode.bankTransfer) ...[
                  _buildPaymentModeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Transfer funds to the designated account for ${_cachedOrgName ?? 'your organization'}, enter your transfer details and upload your payment proof below.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.blue.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Transfer Amount *',
                                  hintText: 'Enter amount paid',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixText: '₦ ',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                final selTotal = items
                                    .where((o) => _selectedObligationIds
                                        .contains(o.id))
                                    .fold(
                                      0.0,
                                      (sum, o) => sum + o.outstandingBalance,
                                    );
                                if (selTotal > 0) {
                                  _customAmountController.text =
                                      selTotal.toStringAsFixed(0);
                                  setState(() {});
                                }
                              },
                              child: const Text('Use Total'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bankNameController,
                          decoration: InputDecoration(
                            labelText: 'Your Issuing Bank *',
                            hintText: 'e.g. Zenith Bank, Access, GTBank',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes / Depositor Name (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        if (_pickedImage != null || _uploadedImageUrl != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _pickedImage != null
                                      ? Image.file(
                                          _pickedImage!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.receipt,
                                          color: Colors.green,
                                          size: 36,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Receipt attached',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        _uploadedImageUrl != null
                                            ? 'Uploaded successfully'
                                            : 'Ready to upload',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isUploading ? null : _pickImage,
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isUploading ? null : _pickImage,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: Text(
                                _isUploading
                                    ? 'Uploading Receipt...'
                                    : 'Upload Transfer Receipt *',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Obligations Selection List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding Obligations',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_paymentMode != PaymentOptionMode.allOutstanding)
                      Text(
                        '${_selectedObligationIds.length} of ${items.length} selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (items.isEmpty)
                  _buildEmptyState('No outstanding obligations')
                else
                  Column(
                    children: items.map((obligation) {
                      final isSelected =
                          _paymentMode == PaymentOptionMode.allOutstanding ||
                              _selectedObligationIds.contains(obligation.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          title: Text(
                            obligation.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Outstanding: ${currency.format(obligation.outstandingBalance)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: obligation.status ==
                                      ObligationStatus.unpaid
                                  ? Colors.red.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              obligation.status == ObligationStatus.unpaid
                                  ? 'Unpaid'
                                  : 'Partial',
                              style: TextStyle(
                                color: obligation.status ==
                                        ObligationStatus.unpaid
                                    ? Colors.red.shade900
                                    : Colors.orange.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          value: isSelected,
                          onChanged: _paymentMode ==
                                  PaymentOptionMode.allOutstanding
                              ? null // All outstanding is lock-selected
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedObligationIds.add(obligation.id);
                                    } else {
                                      _selectedObligationIds
                                          .remove(obligation.id);
                                    }
                                    if (_paymentMode ==
                                            PaymentOptionMode.custom ||
                                        _paymentMode ==
                                            PaymentOptionMode.bankTransfer) {
                                      final total = items
                                          .where((o) => _selectedObligationIds
                                              .contains(o.id))
                                          .fold(
                                            0.0,
                                            (sum, o) =>
                                                sum + o.outstandingBalance,
                                          );
                                      _customAmountController.text =
                                          total.toStringAsFixed(0);
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

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, -2),
                blurRadius: 6,
              ),
            ],
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
                          ? 'Total to Pay:'
                          : 'Total to Pay:',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      currency.format(_getTotalToPay(items)),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isPayButtonEnabled(items, paymentState, offlineState)
                      ? () {
                          if (_paymentMode == PaymentOptionMode.bankTransfer) {
                            _submitTransfer();
                          } else {
                            _initiatePayment(items);
                          }
                        }
                      : null,
                  icon: _getButtonIcon(paymentState, offlineState),
                  label: Text(_getButtonLabel(paymentState, offlineState)),
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
    OfflinePaymentState offlineState,
  ) {
    if (state.isInitializing || state.isVerifying || offlineState.isLoading) {
      return false;
    }
    switch (_paymentMode) {
      case PaymentOptionMode.specific:
        return _selectedObligationIds.isNotEmpty && _getTotalToPay(items) > 0;
      case PaymentOptionMode.allOutstanding:
        return items.isNotEmpty && _getTotalToPay(items) > 0;
      case PaymentOptionMode.custom:
        final customAmount =
            double.tryParse(_customAmountController.text) ?? 0.0;
        return customAmount > 0 && _selectedObligationIds.isNotEmpty;
      case PaymentOptionMode.bankTransfer:
        final amount = double.tryParse(_customAmountController.text) ?? 0.0;
        return amount > 0 &&
            _selectedObligationIds.isNotEmpty &&
            _uploadedImageUrl != null &&
            _bankNameController.text.trim().isNotEmpty;
    }
  }

  Widget _getButtonIcon(
    PaymentFlowState paymentState,
    OfflinePaymentState offlineState,
  ) {
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
    if (paymentState.isInitializing || paymentState.isVerifying) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return const Icon(Icons.lock);
  }

  String _getButtonLabel(
    PaymentFlowState paymentState,
    OfflinePaymentState offlineState,
  ) {
    if (_paymentMode == PaymentOptionMode.bankTransfer) {
      return offlineState.isLoading ? 'Submitting...' : 'Submit Transfer';
    }
    if (paymentState.isInitializing) {
      return 'Connecting to Gateway...';
    }
    if (paymentState.isVerifying) {
      return 'Verifying...';
    }
    final provider = paymentState.selectedProvider;
    switch (provider) {
      case PaymentProvider.paystack:
        return 'Pay with Paystack';
      case PaymentProvider.flutterwave:
        return 'Pay with Flutterwave';
    }
  }

  void _showOnlineGatewayComingSoonDialog(String gatewayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.rocket_launch_outlined,
            color: Colors.blue,
            size: 40,
          ),
        ),
        title: const Text(
          'Coming Soon',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '$gatewayName online card payment is currently under development and will be available in an upcoming update.\n\nPlease proceed using Bank Transfer to submit your payment proof.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.4, fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setPaymentMode(PaymentOptionMode.bankTransfer, _cachedObligations);
            },
            child: const Text('Use Bank Transfer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment(List<ObligationModel> allItems) async {
    final provider = ref.read(paymentFlowProvider).selectedProvider;
    final providerName =
        provider == PaymentProvider.paystack ? 'Paystack' : 'Flutterwave';
    _showOnlineGatewayComingSoonDialog(providerName);
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
      final storageRef = FirebaseStorage.instance.ref(
        'receipts/${widget.memberId}/$fileName',
      );

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await storageRef.putData(bytes);
      } else {
        setState(() {
          _pickedImage = File(picked.path);
        });
        await storageRef.putFile(_pickedImage!);
      }
      final url = await storageRef.getDownloadURL();

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
    if (amount <= 0 || selectedIds.isEmpty || _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in the transfer amount, issuing bank, and upload your receipt.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await ref
        .read(offlinePaymentProvider.notifier)
        .submitBankTransfer(
          memberId: widget.memberId,
          obligationIds: selectedIds,
          amount: amount,
          transferReference: 'TRF-${DateTime.now().millisecondsSinceEpoch}',
          bankName: _bankNameController.text.trim(),
          receiptUrl: _uploadedImageUrl!,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
  }
}
