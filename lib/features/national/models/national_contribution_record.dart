import '../../../core/constants/enums.dart';

class NationalContributionRecord {
  final String paymentId;
  final String memberId;
  final String memberName;
  final String? branchId;
  final String branchName;
  final String levyId;
  final String levyTitle;
  final double amount;
  final DateTime paidAt;
  final PaymentMethod method;

  const NationalContributionRecord({
    required this.paymentId,
    required this.memberId,
    required this.memberName,
    this.branchId,
    required this.branchName,
    required this.levyId,
    required this.levyTitle,
    required this.amount,
    required this.paidAt,
    required this.method,
  });
}
