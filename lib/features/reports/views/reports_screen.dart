import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/reports_provider.dart';
import 'report_preview_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  static final List<_ReportItem> _reports = [
    _ReportItem(
      type: ReportType.memberStatement,
      title: 'Member Statement',
      description:
          'Generate a detailed statement for a specific member including obligations and payments.',
      icon: Icons.person_outline,
    ),
    _ReportItem(
      type: ReportType.levyReport,
      title: 'Levy Report',
      description:
          'View collection status, obligations, and payments for a specific levy.',
      icon: Icons.assessment_outlined,
    ),
    _ReportItem(
      type: ReportType.yearlySummary,
      title: 'Yearly Summary',
      description:
          'Annual financial overview with income, expenses, and net balance.',
      icon: Icons.calendar_today_outlined,
    ),
    _ReportItem(
      type: ReportType.expenseBreakdown,
      title: 'Expense Breakdown',
      description:
          'Detailed expense report grouped by category with date range filtering.',
      icon: Icons.receipt_long_outlined,
    ),
    _ReportItem(
      type: ReportType.financialSummary,
      title: 'Financial Summary',
      description:
          'Overall financial health: collections, expenses, net position, and outstanding obligations.',
      icon: Icons.account_balance_wallet_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  report.icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(report.title),
              subtitle: Text(report.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(selectedReportTypeProvider.notifier).state =
                    report.type;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReportPreviewScreen(reportType: report.type),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReportItem {
  final ReportType type;
  final String title;
  final String description;
  final IconData icon;

  const _ReportItem({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}
