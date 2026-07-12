import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';
import '../../levies/models/levy_model.dart';
import '../../levies/repositories/levy_repository.dart';
import '../../obligations/models/obligation_model.dart';
import '../../obligations/repositories/obligation_repository.dart';
import '../../payments/models/payment_model.dart';
import '../../payments/repositories/payment_repository.dart';
import '../../expenses/models/expense_model.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../services/pdf_service.dart';

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

final reportsMemberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository();
});

final reportsLevyRepositoryProvider = Provider<LevyRepository>((ref) {
  return LevyRepository();
});

final reportsObligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository();
});

final reportsPaymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final reportsExpenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final reportsMembersStreamProvider =
    StreamProvider.autoDispose<List<MemberModel>>((ref) {
      return ref.watch(reportsMemberRepositoryProvider).getMembers();
    });

final reportsAllLeviesStreamProvider =
    StreamProvider.autoDispose<List<LevyModel>>((ref) {
      return ref.watch(reportsLevyRepositoryProvider).getAllLevies();
    });

final reportsAllObligationsStreamProvider =
    StreamProvider.autoDispose<List<ObligationModel>>((ref) {
      return ref.watch(reportsObligationRepositoryProvider).getAllObligations();
    });

final reportsAllPaymentsStreamProvider =
    StreamProvider.autoDispose<List<PaymentModel>>((ref) {
      return ref.watch(reportsPaymentRepositoryProvider).getAllPayments();
    });

final reportsAllExpensesStreamProvider =
    StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
      return ref.watch(reportsExpenseRepositoryProvider).getExpenses();
    });

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
