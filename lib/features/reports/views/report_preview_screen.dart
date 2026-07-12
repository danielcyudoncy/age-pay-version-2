// features/reports/views/report_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../members/models/member_model.dart';
import '../../levies/models/levy_model.dart';
import '../controllers/reports_provider.dart';
import 'pdf_viewer_screen.dart';

class ReportPreviewScreen extends ConsumerStatefulWidget {
  final ReportType reportType;

  const ReportPreviewScreen({super.key, required this.reportType});

  @override
  ConsumerState<ReportPreviewScreen> createState() =>
      _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  bool _isGenerating = false;
  String? _error;

  MemberModel? _selectedMember;
  LevyModel? _selectedLevy;
  int _selectedYear = DateTime.now().year;
  DateTime? _startDate;
  DateTime? _endDate;
  int _totalMembers = 0;

  String get _reportTitle {
    switch (widget.reportType) {
      case ReportType.memberStatement:
        return 'Member Statement';
      case ReportType.levyReport:
        return 'Levy Report';
      case ReportType.yearlySummary:
        return 'Yearly Summary';
      case ReportType.expenseBreakdown:
        return 'Expense Breakdown';
      case ReportType.financialSummary:
        return 'Financial Summary';
    }
  }

  String get _reportDescription {
    switch (widget.reportType) {
      case ReportType.memberStatement:
        return 'Generate a PDF statement for the selected member.';
      case ReportType.levyReport:
        return 'Generate a PDF report for the selected levy.';
      case ReportType.yearlySummary:
        return 'Generate an annual financial summary for the selected year.';
      case ReportType.expenseBreakdown:
        return 'Generate a detailed expense report for the selected date range.';
      case ReportType.financialSummary:
        return 'Generate a comprehensive financial summary.';
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final request = await _buildRequest();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(request: request),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<ReportRequest> _buildRequest() async {
    switch (widget.reportType) {
      case ReportType.memberStatement:
        final member = _selectedMember;
        if (member == null) {
          throw Exception('Please select a member');
        }
        final obligations = await ref
            .read(reportsAllObligationsStreamProvider.future);
        final payments = await ref.read(reportsAllPaymentsStreamProvider.future);

        final memberObligations = obligations
            .where((o) => o.memberId == member.id)
            .toList();
        final memberPayments = payments
            .where((p) => p.memberId == member.id)
            .toList();

        return ReportRequest(
          type: ReportType.memberStatement,
          member: member,
          obligations: memberObligations,
          payments: memberPayments,
          reportDate: DateTime.now(),
        );
      case ReportType.levyReport:
        final levy = _selectedLevy;
        if (levy == null) {
          throw Exception('Please select a levy');
        }
        final obligations = await ref
            .read(reportsAllObligationsStreamProvider.future);
        final payments = await ref.read(reportsAllPaymentsStreamProvider.future);

        final levyObligations = obligations
            .where((o) => o.levyId == levy.id)
            .toList();
        final levyPayments = payments.where((p) {
          return p.allocations.any((a) {
            return levyObligations.any((o) => o.id == a.obligationId);
          });
        }).toList();

        return ReportRequest(
          type: ReportType.levyReport,
          levy: levy,
          obligations: levyObligations,
          payments: levyPayments,
          totalMembers: _totalMembers > 0 ? _totalMembers : null,
        );
      case ReportType.yearlySummary:
        final year = _selectedYear;
        final payments = await ref.read(reportsAllPaymentsStreamProvider.future);
        final expenses = await ref.read(reportsAllExpensesStreamProvider.future);
        final obligations =
            await ref.read(reportsAllObligationsStreamProvider.future);

        final yearPayments = payments.where((p) => p.createdAt.year == year).toList();
        final yearExpenses = expenses.where((e) => e.expenseDate.year == year).toList();
        final yearObligations = obligations
            .where((o) => o.createdAt.year == year)
            .toList();

        return ReportRequest(
          type: ReportType.yearlySummary,
          year: year,
          payments: yearPayments,
          expenses: yearExpenses,
          obligations: yearObligations,
        );
      case ReportType.expenseBreakdown:
        final expenses = await ref.read(reportsAllExpensesStreamProvider.future);
        final filtered = expenses.where((e) {
          if (_startDate == null && _endDate == null) return true;
          if (_startDate != null && e.expenseDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null && e.expenseDate.isAfter(_endDate!)) {
            return false;
          }
          return true;
        }).toList();

        return ReportRequest(
          type: ReportType.expenseBreakdown,
          expenses: filtered,
          startDate: _startDate,
          endDate: _endDate,
        );
      case ReportType.financialSummary:
        final payments = await ref.read(reportsAllPaymentsStreamProvider.future);
        final expenses = await ref.read(reportsAllExpensesStreamProvider.future);
        final members = await ref.read(reportsMembersStreamProvider.future);
        final obligations =
            await ref.read(reportsAllObligationsStreamProvider.future);

        final filteredPayments = payments.where((p) {
          if (_startDate == null && _endDate == null) return true;
          if (_startDate != null && p.createdAt.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null && p.createdAt.isAfter(_endDate!)) {
            return false;
          }
          return true;
        }).toList();
        final filteredExpenses = expenses.where((e) {
          if (_startDate == null && _endDate == null) return true;
          if (_startDate != null && e.expenseDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null && e.expenseDate.isAfter(_endDate!)) {
            return false;
          }
          return true;
        }).toList();

        return ReportRequest(
          type: ReportType.financialSummary,
          payments: filteredPayments,
          expenses: filteredExpenses,
          members: members,
          obligations: obligations,
          startDate: _startDate,
          endDate: _endDate,
        );
    }
  }

  Widget _buildParams(
    AsyncValue<List<MemberModel>> membersAsync,
    AsyncValue<List<LevyModel>> leviesAsync,
  ) {
    switch (widget.reportType) {
      case ReportType.memberStatement:
        return membersAsync.when(
          data: (members) {
            return DropdownButtonFormField<MemberModel>(
              initialValue: _selectedMember,
              decoration: const InputDecoration(labelText: 'Select Member'),
              items: members.map((m) {
                return DropdownMenuItem(value: m, child: Text(m.fullName));
              }).toList(),
              onChanged: (v) => setState(() => _selectedMember = v),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Error loading members: $e'),
        );
      case ReportType.levyReport:
        return Column(
          children: [
            leviesAsync.when(
              data: (levies) {
                return DropdownButtonFormField<LevyModel>(
                  initialValue: _selectedLevy,
                  decoration: const InputDecoration(labelText: 'Select Levy'),
                  items: levies.map((l) {
                    return DropdownMenuItem(value: l, child: Text(l.title));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedLevy = v),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Error loading levies: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _totalMembers > 0 ? '$_totalMembers' : '10',
              decoration: const InputDecoration(labelText: 'Total Members'),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  setState(() => _totalMembers = int.tryParse(v) ?? 0),
            ),
          ],
        );
      case ReportType.yearlySummary:
        return DropdownButtonFormField<int>(
          initialValue: _selectedYear,
          decoration: const InputDecoration(labelText: 'Select Year'),
          items: List.generate(5, (i) {
            final year = DateTime.now().year - 2 + i;
            return DropdownMenuItem(value: year, child: Text('$year'));
          }).toList(),
          onChanged: (v) =>
              setState(() => _selectedYear = v ?? DateTime.now().year),
        );
      case ReportType.expenseBreakdown:
      case ReportType.financialSummary:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                      ),
                      child: Text(
                        _startDate != null
                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Optional',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Date'),
                      child: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Optional',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(reportsMembersStreamProvider);
    final leviesAsync = ref.watch(reportsAllLeviesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_reportTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reportTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reportDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildParams(membersAsync, leviesAsync),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            if (_error != null) const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isGenerating ? 'Generating...' : 'Generate PDF'),
              ),
            ),
            if (_isGenerating)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
