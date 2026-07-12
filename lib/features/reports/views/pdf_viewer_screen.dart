import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../reports/controllers/reports_provider.dart';

class PdfViewerScreen extends ConsumerWidget {
  final ReportRequest request;

  const PdfViewerScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = switch (request.type) {
      ReportType.memberStatement => 'Member Statement',
      ReportType.levyReport => 'Levy Report',
      ReportType.yearlySummary => 'Yearly Summary',
      ReportType.expenseBreakdown => 'Expense Breakdown',
      ReportType.financialSummary => 'Financial Summary',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: () async {
              try {
                final bytes = await ref
                    .read(pdfGenerationProvider(request).future);
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: 'report.pdf',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to share: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) {
          return ref.read(pdfGenerationProvider(request).future);
        },
      ),
    );
  }
}
