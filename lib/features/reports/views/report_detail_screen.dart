import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../controllers/reports_provider.dart';
import '../widgets/expense_breakdown_report_widget.dart';
import '../widgets/financial_summary_report_widget.dart';
import '../widgets/levy_report_widget.dart';
import '../widgets/member_statement_report_widget.dart';
import '../widgets/yearly_summary_report_widget.dart';
import 'pdf_viewer_screen.dart';

class ReportDetailScreen extends ConsumerWidget {
  final ReportRequest request;

  const ReportDetailScreen({super.key, required this.request});

  String get _reportTitle {
    switch (request.type) {
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

  Future<void> _sharePdf(BuildContext context, WidgetRef ref) async {
    try {
      final bytes = await ref.read(pdfGenerationProvider(request).future);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_reportTitle.replaceAll(" ", "_").toLowerCase()}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  void _openPdfViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content;
    switch (request.type) {
      case ReportType.memberStatement:
        content = MemberStatementReportWidget(request: request);
        break;
      case ReportType.levyReport:
        content = LevyReportWidget(request: request);
        break;
      case ReportType.yearlySummary:
        content = YearlySummaryReportWidget(request: request);
        break;
      case ReportType.expenseBreakdown:
        content = ExpenseBreakdownReportWidget(request: request);
        break;
      case ReportType.financialSummary:
        content = FinancialSummaryReportWidget(request: request);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _reportTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'View PDF Document',
            onPressed: () => _openPdfViewer(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: () => _sharePdf(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: content),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openPdfViewer(context),
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  label: const Text('Export / View Official PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
