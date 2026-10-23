// features/reports/views/report_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../members/models/member_model.dart';
import '../../levies/models/levy_model.dart';
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../admin/controllers/admin_provider.dart';
import '../controllers/reports_provider.dart';
import 'report_detail_screen.dart';

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
  String? _selectedMemberId;
  String? _selectedLevyId;
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
          builder: (_) => ReportDetailScreen(request: request),
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
    String? orgName;
    try {
      final orgId = await ref.read(organizationIdProvider.future);
      if (orgId.isNotEmpty) {
        final org = await ref
            .read(organizationRepositoryProvider)
            .getOrganizationById(orgId);
        orgName = org?.name;
      }
    } catch (_) {}

    switch (widget.reportType) {
      case ReportType.memberStatement:
        final members = await ref.read(reportsMembersStreamProvider.future);
        final member = (_selectedMemberId != null
            ? members.where((m) => m.id == _selectedMemberId).firstOrNull
            : null) ?? _selectedMember;
        if (member == null) {
          throw Exception('Please select a member');
        }
        final obligations = await ref
            .read(reportsAllObligationsStreamProvider.future);
        final payments = await ref.read(reportsAllPaymentsStreamProvider.future);

        final memberObligations = obligations.where((o) {
          return o.memberId == member.id ||
              (member.userId.isNotEmpty && o.memberId == member.userId);
        }).toList();

        final memberPayments = payments.where((p) {
          return p.memberId == member.id ||
              (member.userId.isNotEmpty && p.memberId == member.userId);
        }).toList();

        return ReportRequest(
          type: ReportType.memberStatement,
          member: member,
          obligations: memberObligations,
          payments: memberPayments,
          reportDate: DateTime.now(),
          organizationName: orgName,
        );
      case ReportType.levyReport:
        final levies = await ref.read(reportsAllLeviesStreamProvider.future);
        final obligations = await ref
            .read(reportsAllObligationsStreamProvider.future);
        final payments = await ref.read(reportsAllPaymentsStreamProvider.future);
        final members = await ref.read(reportsMembersStreamProvider.future);

        LevyModel? resolvedLevy = (_selectedLevyId != null
            ? levies.where((l) => l.id == _selectedLevyId).firstOrNull
            : null) ?? _selectedLevy;

        if (resolvedLevy == null && _selectedLevyId != null && _selectedLevyId!.startsWith('derived_')) {
          final title = _selectedLevyId!.substring('derived_'.length);
          final matching = obligations.where((o) => o.title.trim() == title.trim()).toList();
          final avgAmount = matching.isNotEmpty ? matching.first.amount : 0.0;
          resolvedLevy = LevyModel(
            id: _selectedLevyId!,
            title: title,
            description: 'Dues category from obligations',
            amountPerMember: avgAmount,
            type: matching.isNotEmpty
                ? matching.first.type
                : ObligationType.specialLevy,
            dueDate: matching.isNotEmpty
                ? matching.first.dueDate
                : DateTime.now(),
            createdBy: '',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
        if (resolvedLevy == null && levies.isNotEmpty) {
          resolvedLevy = levies.first;
        }
        if (resolvedLevy == null) {
          throw Exception('Please select a levy');
        }

        final targetLevy = resolvedLevy;

        final levyObligations = obligations.where((o) {
          return o.levyId == targetLevy.id ||
              (targetLevy.id.startsWith('derived_') && o.title.trim() == targetLevy.title.trim());
        }).toList();

        final levyPayments = payments.where((p) {
          return p.allocations.any((a) {
            return levyObligations.any((o) => o.id == a.obligationId);
          });
        }).toList();

        return ReportRequest(
          type: ReportType.levyReport,
          levy: targetLevy,
          obligations: levyObligations,
          payments: levyPayments,
          members: members,
          totalMembers: _totalMembers > 0
              ? _totalMembers
              : (levyObligations.isNotEmpty ? levyObligations.length : null),
          organizationName: orgName,
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
            .where((o) =>
                o.createdAt.year == year ||
                (o.settledAt != null && o.settledAt!.year == year) ||
                o.dueDate.year == year)
            .toList();

        return ReportRequest(
          type: ReportType.yearlySummary,
          year: year,
          payments: yearPayments,
          expenses: yearExpenses,
          obligations: yearObligations,
          organizationName: orgName,
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
          organizationName: orgName,
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
          organizationName: orgName,
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
            final currentSelectedId = (_selectedMemberId != null &&
                    members.any((m) => m.id == _selectedMemberId))
                ? _selectedMemberId
                : (members.isNotEmpty ? members.first.id : null);
            _selectedMemberId = currentSelectedId;

            return DropdownButtonFormField<String>(
              key: ValueKey('member_$currentSelectedId'),
              initialValue: currentSelectedId,
              decoration: const InputDecoration(labelText: 'Select Member'),
              items: members.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Text(m.fullName),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedMemberId = v;
                    _selectedMember =
                        members.where((m) => m.id == v).firstOrNull;
                  });
                }
              },
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
        final obligationsAsync = ref.watch(reportsAllObligationsStreamProvider);
        return Column(
          children: [
            leviesAsync.when(
              data: (levies) {
                final availableLevies = [...levies];
                if (availableLevies.isEmpty) {
                  final obligations = obligationsAsync.valueOrNull ?? [];
                  final titles = obligations
                      .map((o) => o.title.trim())
                      .where((t) => t.isNotEmpty)
                      .toSet();
                  for (final t in titles) {
                    final matching = obligations.where((o) => o.title.trim() == t).toList();
                    final avgAmount = matching.isNotEmpty ? matching.first.amount : 0.0;
                    availableLevies.add(
                      LevyModel(
                        id: 'derived_$t',
                        title: t,
                        description: 'Dues category from obligations',
                        amountPerMember: avgAmount,
                        type: matching.isNotEmpty
                            ? matching.first.type
                            : ObligationType.specialLevy,
                        dueDate: matching.isNotEmpty
                            ? matching.first.dueDate
                            : DateTime.now(),
                        createdBy: '',
                        isActive: true,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }
                }

                if (availableLevies.isEmpty) {
                  return Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No levies or dues records found to generate a report.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final currentSelectedId = (_selectedLevyId != null &&
                        availableLevies.any((l) => l.id == _selectedLevyId))
                    ? _selectedLevyId
                    : (availableLevies.isNotEmpty ? availableLevies.first.id : null);
                _selectedLevyId = currentSelectedId;

                return DropdownButtonFormField<String>(
                  key: ValueKey('levy_$currentSelectedId'),
                  initialValue: currentSelectedId,
                  decoration: const InputDecoration(
                    labelText: 'Select Levy / Dues Category',
                  ),
                  items: availableLevies.map((l) {
                    return DropdownMenuItem<String>(
                      value: l.id,
                      child: Text(l.title),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedLevyId = v;
                        _selectedLevy =
                            availableLevies.where((l) => l.id == v).firstOrNull;
                      });
                    }
                  },
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
              initialValue: _totalMembers > 0 ? '$_totalMembers' : '',
              decoration: const InputDecoration(
                labelText: 'Total Members (Optional override)',
                hintText: 'Leave blank to use actual assigned members',
              ),
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
      appBar: AppBar(
        centerTitle: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_reportTitle),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
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
                    : const Icon(Icons.analytics_outlined),
                label: Text(_isGenerating ? 'Loading Report...' : 'View Report'),
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
