// features/reports/screens/report_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/models.dart';
import '../providers/reports_provider.dart';

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

  // Parameters
  MemberModel? _selectedMember;
  LevyModel? _selectedLevy;
  int _selectedYear = DateTime.now().year;
  DateTime? _startDate;
  DateTime? _endDate;
  int _totalMembers = 0;

  // Placeholder data for dropdowns
  final List<MemberModel> _placeholderMembers = [
    MemberModel(
      id: 'm1',
      userId: 'u1',
      fullName: 'John Doe',
      email: 'john@test.com',
      phoneNumber: '+2348012345678',
      dateOfBirth: DateTime(1990, 1, 1),
      joinedDate: DateTime(2020, 1, 1),
      isActive: true,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ),
    MemberModel(
      id: 'm2',
      userId: 'u2',
      fullName: 'Jane Smith',
      email: 'jane@test.com',
      phoneNumber: '+2348098765432',
      dateOfBirth: DateTime(1992, 5, 10),
      joinedDate: DateTime(2021, 3, 15),
      isActive: true,
      createdAt: DateTime(2021, 3, 15),
      updatedAt: DateTime(2024, 1, 1),
    ),
  ];

  final List<LevyModel> _placeholderLevies = [
    LevyModel(
      id: 'l1',
      title: 'Annual Dues 2024',
      description: 'Annual membership dues',
      type: ObligationType.monthlyDue,
      amountPerMember: 12000.0,
      dueDate: DateTime(2024, 12, 31),
      createdBy: 'admin',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ),
    LevyModel(
      id: 'l2',
      title: 'Building Project Levy',
      description: 'Community hall construction',
      type: ObligationType.projectContribution,
      amountPerMember: 50000.0,
      dueDate: DateTime(2024, 6, 30),
      createdBy: 'admin',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ),
  ];

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
      final request = _buildRequest();
      final pdfBytes = await ref.read(pdfGenerationProvider(request).future);

      if (!mounted) return;

      await Printing.sharePdf(bytes: pdfBytes, filename: '$_fileName.pdf');
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

  ReportRequest _buildRequest() {
    switch (widget.reportType) {
      case ReportType.memberStatement:
        return ReportRequest(
          type: ReportType.memberStatement,
          member: _selectedMember ?? _placeholderMembers.first,
          obligations: const [],
          payments: const [],
          reportDate: DateTime.now(),
        );
      case ReportType.levyReport:
        return ReportRequest(
          type: ReportType.levyReport,
          levy: _selectedLevy ?? _placeholderLevies.first,
          obligations: const [],
          payments: const [],
          totalMembers: _totalMembers > 0 ? _totalMembers : 10,
        );
      case ReportType.yearlySummary:
        return ReportRequest(
          type: ReportType.yearlySummary,
          year: _selectedYear,
          payments: const [],
          expenses: const [],
          obligations: const [],
        );
      case ReportType.expenseBreakdown:
        return ReportRequest(
          type: ReportType.expenseBreakdown,
          expenses: const [],
          startDate: _startDate,
          endDate: _endDate,
        );
      case ReportType.financialSummary:
        return ReportRequest(
          type: ReportType.financialSummary,
          payments: const [],
          expenses: const [],
          members: const [],
          obligations: const [],
          startDate: _startDate,
          endDate: _endDate,
        );
    }
  }

  String get _fileName {
    final now = DateTime.now();
    final ts =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    switch (widget.reportType) {
      case ReportType.memberStatement:
        return 'member_statement_$ts';
      case ReportType.levyReport:
        return 'levy_report_$ts';
      case ReportType.yearlySummary:
        return 'yearly_summary_$_selectedYear';
      case ReportType.expenseBreakdown:
        return 'expense_breakdown_$ts';
      case ReportType.financialSummary:
        return 'financial_summary_$ts';
    }
  }

  Widget _buildParams() {
    switch (widget.reportType) {
      case ReportType.memberStatement:
        return DropdownButtonFormField<MemberModel>(
          initialValue: _selectedMember,
          decoration: const InputDecoration(labelText: 'Select Member'),
          items: _placeholderMembers.map((m) {
            return DropdownMenuItem(value: m, child: Text(m.fullName));
          }).toList(),
          onChanged: (v) => setState(() => _selectedMember = v),
        );
      case ReportType.levyReport:
        return Column(
          children: [
            DropdownButtonFormField<LevyModel>(
              initialValue: _selectedLevy,
              decoration: const InputDecoration(labelText: 'Select Levy'),
              items: _placeholderLevies.map((l) {
                return DropdownMenuItem(value: l, child: Text(l.title));
              }).toList(),
              onChanged: (v) => setState(() => _selectedLevy = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '10',
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
                    _buildParams(),
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
