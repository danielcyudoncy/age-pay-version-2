import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/services/pdf_service.dart';

enum ReportType {
  memberStatement,
  levyReport,
  yearlySummary,
  expenseBreakdown,
  financialSummary,
}

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

final selectedReportTypeProvider = StateProvider<ReportType?>((ref) => null);

final reportParamsProvider = StateProvider<Map<String, dynamic>>((ref) => {});

final pdfGenerationProvider = FutureProvider.family<Uint8List, ReportRequest>((
  ref,
  request,
) async {
  final pdfService = ref.read(pdfServiceProvider);

  switch (request.type) {
    case ReportType.memberStatement:
      return pdfService.generateMemberStatement(
        member: request.member!,
        obligations: request.obligations,
        payments: request.payments,
        reportDate: request.reportDate ?? DateTime.now(),
      );
    case ReportType.levyReport:
      return pdfService.generateLevyReport(
        levy: request.levy!,
        obligations: request.obligations,
        payments: request.payments,
        totalMembers: request.totalMembers ?? 0,
      );
    case ReportType.yearlySummary:
      return pdfService.generateYearlySummary(
        year: request.year ?? DateTime.now().year,
        payments: request.payments,
        expenses: request.expenses,
        obligations: request.obligations,
      );
    case ReportType.expenseBreakdown:
      return pdfService.generateExpenseBreakdown(
        expenses: request.expenses,
        startDate: request.startDate,
        endDate: request.endDate,
      );
    case ReportType.financialSummary:
      return pdfService.generateFinancialSummary(
        payments: request.payments,
        expenses: request.expenses,
        members: request.members,
        obligations: request.obligations,
        startDate: request.startDate,
        endDate: request.endDate,
      );
  }
});

class ReportRequest {
  final ReportType type;
  final MemberModel? member;
  final LevyModel? levy;
  final List<ObligationModel> obligations;
  final List<PaymentModel> payments;
  final List<ExpenseModel> expenses;
  final List<MemberModel> members;
  final DateTime? reportDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? year;
  final int? totalMembers;

  const ReportRequest({
    required this.type,
    this.member,
    this.levy,
    this.obligations = const [],
    this.payments = const [],
    this.expenses = const [],
    this.members = const [],
    this.reportDate,
    this.startDate,
    this.endDate,
    this.year,
    this.totalMembers,
  });
}
