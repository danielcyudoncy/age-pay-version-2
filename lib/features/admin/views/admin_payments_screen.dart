import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../payments/models/payment_model.dart';
import '../../payments/views/transfer_proof_screen.dart';
import '../../dashboard/controllers/treasurer_dashboard_provider.dart';

class AdminPaymentsScreen extends ConsumerStatefulWidget {
  final bool filterPendingOnly;

  const AdminPaymentsScreen({
    super.key,
    this.filterPendingOnly = false,
  });

  @override
  ConsumerState<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'All'; // 'All', 'Approved', 'Pending', 'Rejected'
  PaymentMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    if (widget.filterPendingOnly) {
      _statusFilter = 'Pending';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentsAsync = ref.watch(allPaymentsStreamProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Ledger & Audits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Ledger',
            onPressed: () => ref.invalidate(allPaymentsStreamProvider),
          ),
        ],
      ),
      body: paymentsAsync.when(
        data: (allPayments) {
          final approvedPayments = allPayments.where(
            (p) => p.status == PaymentStatus.approved,
          );
          final pendingPayments = allPayments.where(
            (p) => p.status == PaymentStatus.pending,
          );
          final totalCollected = approvedPayments.fold<double>(
            0.0,
            (sum, p) => sum + p.amount,
          );

          // Apply filters
          final filtered = allPayments.where((payment) {
            // 1. Search Query
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final nameMatch = payment.memberName?.toLowerCase().contains(q) ?? false;
              final refMatch = payment.paystackReference?.toLowerCase().contains(q) ?? false;
              final noteMatch = payment.notes?.toLowerCase().contains(q) ?? false;
              final amountMatch = payment.amount.toString().contains(q);
              if (!nameMatch && !refMatch && !noteMatch && !amountMatch) {
                return false;
              }
            }

            // 2. Status filter
            if (_statusFilter == 'Approved' && payment.status != PaymentStatus.approved) {
              return false;
            }
            if (_statusFilter == 'Pending' && payment.status != PaymentStatus.pending) {
              return false;
            }
            if (_statusFilter == 'Rejected' && payment.status != PaymentStatus.rejected) {
              return false;
            }

            // 3. Payment Method filter
            if (_selectedMethod != null && payment.method != _selectedMethod) {
              return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Search & Filter header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by member, reference, notes, amount...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
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
                  onChanged: (val) {
                    setState(() => _query = val.trim().toLowerCase());
                  },
                ),
              ),

              // KPI Header Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppTheme.primary(context).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL COLLECTED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: AppTheme.primary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                currency.format(totalCollected),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${approvedPayments.length} txns',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pendingPayments.isNotEmpty
                              ? Colors.amber.shade50
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pendingPayments.isNotEmpty
                                ? Colors.amber.shade300
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: pendingPayments.isNotEmpty
                                    ? Colors.amber.shade900
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pendingPayments.length} proof(s)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: pendingPayments.isNotEmpty
                                    ? Colors.amber.shade900
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected'),
                    const SizedBox(width: 12),
                    // Method filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PaymentMethod?>(
                          value: _selectedMethod,
                          hint: const Text('All Payment Channels', style: TextStyle(fontSize: 12)),
                          isDense: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Channels', style: TextStyle(fontSize: 12)),
                            ),
                            const DropdownMenuItem(
                              value: PaymentMethod.bankTransfer,
                              child: Text('Bank Transfer', style: TextStyle(fontSize: 12)),
                            ),
                            const DropdownMenuItem(
                              value: PaymentMethod.online,
                              child: Text('Online (Paystack)', style: TextStyle(fontSize: 12)),
                            ),
                            const DropdownMenuItem(
                              value: PaymentMethod.cash,
                              child: Text('Cash', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedMethod = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Transaction List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allPayments.isEmpty
                                  ? 'No payments recorded on platform yet'
                                  : 'No payments match your filter criteria',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final payment = filtered[index];
                          return _buildPaymentCard(
                            context,
                            theme,
                            payment,
                            currency,
                            dateFormat,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load ledger: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(allPaymentsStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = label);
      },
      selectedColor: AppTheme.primaryContainer(context),
      checkmarkColor: AppTheme.primary(context),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary(context) : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    ThemeData theme,
    PaymentModel payment,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final (statusColor, statusBg, statusText) = switch (payment.status) {
      PaymentStatus.approved => (
          AppTheme.statusColor(context, Colors.green),
          AppTheme.statusBg(context, Colors.green),
          'Approved',
        ),
      PaymentStatus.pending => (
          AppTheme.statusColor(context, Colors.amber),
          AppTheme.statusBg(context, Colors.amber),
          'Pending Verification',
        ),
      PaymentStatus.rejected => (
          AppTheme.statusColor(context, Colors.red),
          AppTheme.statusBg(context, Colors.red),
          'Rejected',
        ),
    };

    final (methodIcon, methodLabel) = switch (payment.method) {
      PaymentMethod.bankTransfer => (Icons.account_balance, 'Bank Transfer'),
      PaymentMethod.online => (Icons.credit_card, 'Paystack Online'),
      PaymentMethod.cash => (Icons.payments_outlined, 'Cash Collection'),
    };

    final memberDisplayName = payment.memberName?.isNotEmpty == true
        ? payment.memberName!
        : 'Member ID: ${payment.memberId.substring(0, (payment.memberId.length > 8 ? 8 : payment.memberId.length))}';

    final hasProof = payment.transferProofUrl?.isNotEmpty == true ||
        payment.receiptUrl?.isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Member Name & Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryContainer(context),
                  child: Text(
                    memberDisplayName.isNotEmpty ? memberDisplayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppTheme.primary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(methodIcon, size: 12, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            methodLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(payment.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: payment.status == PaymentStatus.approved
                            ? Colors.green.shade800
                            : (payment.status == PaymentStatus.rejected
                                ? Colors.red.shade700
                                : Colors.amber.shade900),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Row 2: Date, Reference, Notes, and Proof Button
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(payment.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (payment.paystackReference != null) ...[
                  Text(
                    'Ref: ${payment.paystackReference}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (hasProof) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransferProofScreen(payment: payment),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_outlined, size: 12, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'View Slip',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (payment.notes != null && payment.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note: ${payment.notes!}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
