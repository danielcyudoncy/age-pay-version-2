import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/models/expense_model.dart';
import '../../national/models/national_remittance_model.dart';
import '../../payments/models/payment_model.dart';
import '../controllers/reports_provider.dart';

class AgmFinancialReportWidget extends StatefulWidget {
  final ReportRequest request;

  const AgmFinancialReportWidget({super.key, required this.request});

  @override
  State<AgmFinancialReportWidget> createState() => _AgmFinancialReportWidgetState();
}

class _AgmFinancialReportWidgetState extends State<AgmFinancialReportWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isRegistration(PaymentModel p) {
    final note = (p.notes ?? '').toLowerCase();
    return note.contains('reg') ||
        note.contains('admission') ||
        note.contains('drink') ||
        p.allocations.any((a) => a.obligationId.toLowerCase().contains('reg'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final period = request.fiscalPeriod;
    final payments = request.payments;
    final expenses = request.expenses;
    final remittances = request.remittances;

    final startDate = request.startDate ?? period?.startDate ?? DateTime(2025, 7, 1);
    final endDate = request.endDate ?? period?.endDate ?? DateTime(2026, 10, 31);
    final balBf = period?.openingBalance ?? 0.0;

    // Filter payments in tenure period
    final approvedPayments = payments.where((p) {
      if (p.createdAt.isBefore(startDate)) return false;
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      if (p.createdAt.isAfter(endOfDay)) return false;
      return true;
    }).toList();

    // Dues vs Registration payments
    final regPayments = approvedPayments.where(_isRegistration).toList();
    final duesPayments = approvedPayments.where((p) => !_isRegistration(p)).toList();

    final duesTotal = duesPayments.fold<double>(0.0, (s, p) => s + p.amount);
    final regTotal = regPayments.fold<double>(0.0, (s, p) => s + p.amount);
    final branchIncomeSubtotal = duesTotal + regTotal;

    // National collections (Custodial pass-through)
    final nationalSubtotal = remittances.fold<double>(
      0.0,
      (s, r) => s + r.unremittedBalance,
    );

    final totalGrossValue = balBf + branchIncomeSubtotal + nationalSubtotal;

    // Filter expenses in tenure period
    final periodExpenses = expenses.where((e) {
      if (e.expenseDate.isBefore(startDate)) return false;
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      if (e.expenseDate.isAfter(endOfDay)) return false;
      return true;
    }).toList();

    final totalExpenses = periodExpenses.fold<double>(0.0, (s, e) => s + e.amount);
    final balAtHandAndBank = totalGrossValue - totalExpenses;

    final orgName = request.organizationName ?? 'Association';
    final branchName = request.branchName ?? '';

    // Group dues by month
    final Map<String, List<PaymentModel>> duesByMonth = {};
    for (final p in duesPayments) {
      final key = DateFormat('MMMM yyyy').format(p.createdAt);
      (duesByMonth[key] ??= []).add(p);
    }
    final sortedDuesMonthEntries = duesByMonth.entries.toList()
      ..sort((a, b) {
        final aDate = a.value.first.createdAt;
        final bDate = b.value.first.createdAt;
        return aDate.compareTo(bDate);
      });

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.brandGreen,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart), text: 'Page 1: Statement'),
            Tab(icon: Icon(Icons.notes), text: 'Pages 2–4: Notes to Account'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPageOneStatement(
                theme: theme,
                orgName: orgName,
                branchName: branchName,
                startDate: startDate,
                endDate: endDate,
                balBf: balBf,
                duesTotal: duesTotal,
                regTotal: regTotal,
                branchIncomeSubtotal: branchIncomeSubtotal,
                remittances: remittances,
                nationalSubtotal: nationalSubtotal,
                totalGrossValue: totalGrossValue,
                periodExpenses: periodExpenses,
                totalExpenses: totalExpenses,
                balAtHandAndBank: balAtHandAndBank,
              ),
              _buildPagesNotesToAccount(
                theme: theme,
                sortedDuesMonthEntries: sortedDuesMonthEntries,
                duesTotal: duesTotal,
                regPayments: regPayments,
                regTotal: regTotal,
                remittances: remittances,
                periodExpenses: periodExpenses,
                balBf: balBf,
                branchIncomeSubtotal: branchIncomeSubtotal,
                nationalSubtotal: nationalSubtotal,
                totalGrossValue: totalGrossValue,
                totalExpenses: totalExpenses,
                balAtHandAndBank: balAtHandAndBank,
                endDate: endDate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageOneStatement({
    required ThemeData theme,
    required String orgName,
    required String branchName,
    required DateTime startDate,
    required DateTime endDate,
    required double balBf,
    required double duesTotal,
    required double regTotal,
    required double branchIncomeSubtotal,
    required List<NationalRemittanceModel> remittances,
    required double nationalSubtotal,
    required double totalGrossValue,
    required List<ExpenseModel> periodExpenses,
    required double totalExpenses,
    required double balAtHandAndBank,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Official Document Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                orgName.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (branchName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  branchName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Financial Report as at ${_dateFormat.format(endDate)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.brandGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tenure Period: ${_dateFormat.format(startDate)} \u2013 ${_dateFormat.format(endDate)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Net Liquidity KPI Card
        Card(
          elevation: 0,
          color: Colors.teal.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.teal, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bal at Hand / Bank',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _currency.format(balAtHandAndBank),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text(
                    'Reconciled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // The Formal Accounting Ledger Table Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: Colors.grey.shade100,
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'PARTICULARS & NOTES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Text(
                      'AMOUNT (₦)',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 1. Bal b/f
              _buildLedgerRow(
                title: 'Bal b/f (${_dateFormat.format(startDate)})',
                amount: _currency.format(balBf),
                isBold: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),

              // 2. Branch Receipts (Inflows)
              _buildSectionHeader('Branch Receipts (Inflows)'),
              _buildLedgerRow(
                title: 'Dues Collected',
                noteRef: 'Note 1',
                amount: _currency.format(duesTotal),
              ),
              _buildLedgerRow(
                title: 'New Registration Fees',
                noteRef: 'Note 2',
                amount: _currency.format(regTotal),
              ),
              _buildLedgerRow(
                title: 'Subtotal Branch Receipts',
                amount: _currency.format(branchIncomeSubtotal),
                isSubtotal: true,
                showTopBorder: true,
                backgroundColor: Colors.grey.shade50,
              ),

              // 3. Pass-Through / National Escrow (Custodial)
              _buildSectionHeader('Pass-Through / National Escrow (Custodial)'),
              if (remittances.isEmpty) ...[
                _buildLedgerRow(
                  title: 'No unremitted national levies',
                  amount: '₦0',
                  textColor: Colors.grey,
                ),
              ] else ...[
                ...remittances.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  return _buildLedgerRow(
                    title: '${r.levyTitle} (Unremitted)',
                    noteRef: 'Note ${3 + idx}',
                    amount: _currency.format(r.unremittedBalance),
                  );
                }),
              ],
              _buildLedgerRow(
                title: 'Subtotal National Escrow',
                amount: _currency.format(nationalSubtotal),
                isSubtotal: true,
                showTopBorder: true,
                backgroundColor: Colors.grey.shade50,
              ),

              // Total Gross Value
              _buildLedgerRow(
                title: 'Total Gross Value',
                amount: _currency.format(totalGrossValue),
                isBold: true,
                fontSize: 14,
                textColor: Colors.blue.shade900,
                backgroundColor: Colors.blue.withValues(alpha: 0.08),
                showTopBorder: true,
                showBottomBorder: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),

              // 4. Less Operating Disbursements
              _buildSectionHeader('Less Operating Disbursements (Expenses)'),
              if (periodExpenses.isEmpty) ...[
                _buildLedgerRow(
                  title: 'No operating disbursements recorded',
                  amount: '₦0',
                  textColor: Colors.grey,
                ),
              ] else ...[
                ...periodExpenses.map((e) {
                  return _buildLedgerRow(
                    title: e.title,
                    noteRef: e.noteRef,
                    amount: _currency.format(e.amount),
                  );
                }),
              ],

              // Total Disbursements
              _buildLedgerRow(
                title: 'Total Disbursements',
                amount: '(${_currency.format(totalExpenses)})',
                isBold: true,
                fontSize: 13,
                textColor: Colors.red.shade800,
                backgroundColor: Colors.red.withValues(alpha: 0.05),
                showTopBorder: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),

              // 5. Final Closing Balance
              _buildLedgerRow(
                title: 'Bal at hand / Bank',
                amount: _currency.format(balAtHandAndBank),
                isBold: true,
                fontSize: 15,
                textColor: AppTheme.brandGreen,
                backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.12),
                isClosingDoubleBorder: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Signatures Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 1, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      const Text(
                        'Prepared by: Financial Secretary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const Text(
                        'Accounting & Bookkeeper',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 1, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      const Text(
                        'Certified by: Treasurer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const Text(
                        'Fund Custodian & Banker',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: Colors.grey.shade100,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildLedgerRow({
    required String title,
    String? noteRef,
    required String amount,
    bool isSubtotal = false,
    bool isBold = false,
    bool isItalic = false,
    Color? textColor,
    Color? backgroundColor,
    bool showTopBorder = false,
    bool showBottomBorder = false,
    bool isClosingDoubleBorder = false,
    double fontSize = 13,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: showTopBorder
              ? BorderSide(color: Colors.grey.shade300, width: 0.8)
              : BorderSide.none,
          bottom: isClosingDoubleBorder
              ? const BorderSide(color: AppTheme.brandGreen, width: 2.5)
              : (showBottomBorder
                  ? BorderSide(color: Colors.grey.shade300, width: 0.8)
                  : BorderSide.none),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isBold
                          ? FontWeight.bold
                          : (isSubtotal ? FontWeight.w600 : FontWeight.normal),
                      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                      color: textColor ?? Colors.black87,
                    ),
                  ),
                ),
                if (noteRef != null && noteRef.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppTheme.brandGreen.withValues(alpha: 0.3),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      noteRef,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.brandGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amount,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold || isSubtotal ? FontWeight.bold : FontWeight.w600,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesNotesToAccount({
    required ThemeData theme,
    required List<MapEntry<String, List<PaymentModel>>> sortedDuesMonthEntries,
    required double duesTotal,
    required List<PaymentModel> regPayments,
    required double regTotal,
    required List<NationalRemittanceModel> remittances,
    required List<ExpenseModel> periodExpenses,
    required double balBf,
    required double branchIncomeSubtotal,
    required double nationalSubtotal,
    required double totalGrossValue,
    required double totalExpenses,
    required double balAtHandAndBank,
    required DateTime endDate,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'NOTES TO THE ACCOUNT',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.brandGreen,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Detailed schedules and explanations corresponding to items in the financial statement.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Note 1: Dues Collections Schedule
        _buildDuesScheduleCard(
          sortedMonthEntries: sortedDuesMonthEntries,
          duesTotal: duesTotal,
        ),

        // Note 2: New Member Registrations
        _buildRegistrationsCard(
          regPayments: regPayments,
          regTotal: regTotal,
        ),

        // Notes for National Remittances
        if (remittances.isEmpty) ...[
          _buildEmptyNationalRemittanceCard(),
        ] else ...[
          ...remittances.asMap().entries.map((entry) {
            final idx = entry.key;
            final r = entry.value;
            return _buildNationalRemittanceNoteCard(
              noteNumber: 'Note ${3 + idx}',
              remittance: r,
            );
          }),
        ],

        // Notes for Operating Disbursements (Expenses)
        if (periodExpenses.isEmpty) ...[
          _buildEmptyExpensesCard(),
        ] else ...[
          ...periodExpenses.asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final noteLabel = e.noteRef != null && e.noteRef!.isNotEmpty
                ? e.noteRef!
                : 'Expense #${idx + 1}';
            return _buildExpenseNoteCard(
              noteLabel: noteLabel,
              expense: e,
            );
          }),
        ],

        // Final Note: Liquidity Reconciliation
        _buildReconciliationNoteCard(
          balBf: balBf,
          branchIncomeSubtotal: branchIncomeSubtotal,
          nationalSubtotal: nationalSubtotal,
          totalGrossValue: totalGrossValue,
          totalExpenses: totalExpenses,
          balAtHandAndBank: balAtHandAndBank,
          endDate: endDate,
        ),
      ],
    );
  }

  Widget _buildDuesScheduleCard({
    required List<MapEntry<String, List<PaymentModel>>> sortedMonthEntries,
    required double duesTotal,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.brandGreen.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: const Text(
                    'Note 1',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dues Collections Schedule',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Detailed monthly breakdown of contributions received during tenure',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            if (sortedMonthEntries.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'No dues collections recorded for this tenure period. Total: ₦0',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'MONTH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Text(
                            'AMOUNT (₦)',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...sortedMonthEntries.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final monthKey = entry.value.key;
                      final payments = entry.value.value;
                      final monthSum = payments.fold<double>(0.0, (s, p) => s + p.amount);
                      final isEven = idx % 2 == 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: isEven ? Colors.white : Colors.grey.shade50,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: AppTheme.brandGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    monthKey,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${payments.length} ${payments.length == 1 ? 'payment' : 'payments'} recorded',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _currency.format(monthSum),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: AppTheme.brandGreen.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TOTAL DUES COLLECTED',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AppTheme.brandGreen,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _currency.format(duesTotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationsCard({
    required List<PaymentModel> regPayments,
    required double regTotal,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.brandGreen.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: const Text(
                    'Note 2',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'New Member Registrations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Admission fees and registration charges received from new members',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            if (regPayments.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'No new member registration fees recorded during this tenure period. Total: ₦0',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'DATE & DETAILS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Text(
                            'AMOUNT (₦)',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...regPayments.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      final isEven = idx % 2 == 0;
                      final noteText = p.notes != null && p.notes!.isNotEmpty
                          ? p.notes!
                          : 'New Member Registration';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: isEven ? Colors.white : Colors.grey.shade50,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 16,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dateFormat.format(p.createdAt),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    noteText,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _currency.format(p.amount),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: AppTheme.brandGreen.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TOTAL REGISTRATION FEES',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AppTheme.brandGreen,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _currency.format(regTotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNationalRemittanceCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Note 3',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'National Levies & Pass-Through Escrow',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No pass-through national levies recorded for this tenure period. Total: ₦0',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNationalRemittanceNoteCard({
    required String noteNumber,
    required NationalRemittanceModel remittance,
  }) {
    final r = remittance;
    final isFullyRemitted = r.unremittedBalance <= 0;
    final isPartiallyRemitted = !isFullyRemitted && r.amountRemitted > 0;
    final statusColor = isFullyRemitted
        ? Colors.green
        : (isPartiallyRemitted ? Colors.orange : Colors.grey.shade700);
    final statusText = isFullyRemitted
        ? 'Fully Remitted'
        : (isPartiallyRemitted ? 'Partially Remitted' : 'Pending Remittance');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.brandGreen.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    noteNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${r.levyTitle} (National Custodial)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Custodial pass-through funds held in trust for National Secretariat',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildNoteKeyValueRow(
                    label: 'Total Collected from Members',
                    value: _currency.format(r.totalCollected),
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Remitted to National HQ',
                    value: '(${_currency.format(r.amountRemitted)})',
                    valueColor: Colors.blue.shade700,
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Unremitted Balance (Held in Trust)',
                    value: _currency.format(r.unremittedBalance),
                    isBold: true,
                    valueColor: AppTheme.brandGreen,
                    backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.06),
                  ),
                ],
              ),
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.notes!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExpensesCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Expenses',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Operating Disbursements',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No operating expenses or disbursements recorded during this tenure period. Total: ₦0',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseNoteCard({
    required String noteLabel,
    required ExpenseModel expense,
  }) {
    final e = expense;
    final isCoFunded = (e.grossAmount != null && e.grossAmount! > 0) ||
        (e.contributionsDeduction != null && e.contributionsDeduction! > 0);
    final gross = e.grossAmount ?? e.amount;
    final deduction = e.contributionsDeduction ?? 0.0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.brandGreen.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    noteLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text(
                  _dateFormat.format(e.expenseDate),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.category.displayName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
                if (isCoFunded) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Co-Funded Event',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (isCoFunded) ...[
                    _buildNoteKeyValueRow(
                      label: 'Gross Expenditure',
                      value: _currency.format(gross),
                    ),
                    const Divider(height: 1),
                    _buildNoteKeyValueRow(
                      label: 'Less Member Voluntary Donations',
                      value: '(${_currency.format(deduction)})',
                      valueColor: Colors.orange.shade800,
                    ),
                    const Divider(height: 1),
                  ],
                  _buildNoteKeyValueRow(
                    label: 'Net Purse Disbursed',
                    value: _currency.format(e.amount),
                    isBold: true,
                    valueColor: Colors.red.shade800,
                    backgroundColor: Colors.red.withValues(alpha: 0.04),
                  ),
                ],
              ),
            ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Details: ${e.description}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationNoteCard({
    required double balBf,
    required double branchIncomeSubtotal,
    required double nationalSubtotal,
    required double totalGrossValue,
    required double totalExpenses,
    required double balAtHandAndBank,
    required DateTime endDate,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.brandGreen.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: const Text(
                    'Reconciliation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Summary of Bank & Cash at Hand',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Closing liquidity reconciliation as at ${_dateFormat.format(endDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildNoteKeyValueRow(
                    label: 'Balance Brought Forward (Bal b/f)',
                    value: _currency.format(balBf),
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Total Branch Inflows (Dues & Regs)',
                    value: '+ ${_currency.format(branchIncomeSubtotal)}',
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Total Custodial National Escrow',
                    value: '+ ${_currency.format(nationalSubtotal)}',
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Total Gross Value Available',
                    value: '= ${_currency.format(totalGrossValue)}',
                    isBold: true,
                    valueColor: Colors.blue.shade900,
                    backgroundColor: Colors.blue.withValues(alpha: 0.08),
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Less Total Operating Disbursements',
                    value: '- (${_currency.format(totalExpenses)})',
                    isBold: true,
                    valueColor: Colors.red.shade800,
                    backgroundColor: Colors.red.withValues(alpha: 0.04),
                  ),
                  const Divider(height: 1),
                  _buildNoteKeyValueRow(
                    label: 'Bal at hand / Bank (Closing Balance)',
                    value: _currency.format(balAtHandAndBank),
                    isBold: true,
                    valueColor: AppTheme.brandGreen,
                    backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.12),
                    isDoubleBorderBottom: true,
                    fontSize: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteKeyValueRow({
    required String label,
    required String value,
    bool isBold = false,
    Color? valueColor,
    Color? backgroundColor,
    bool isDoubleBorderBottom = false,
    double fontSize = 13,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        border: isDoubleBorderBottom
            ? const Border(bottom: BorderSide(color: AppTheme.brandGreen, width: 2.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80, maxWidth: 130),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
