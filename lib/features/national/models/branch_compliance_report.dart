class BranchComplianceReport {
  final String branchId;
  final String branchName;
  final String state;
  final String city;
  final bool isNational;
  final int memberCount;
  final double totalExpected;
  final double totalRemitted;
  final double outstandingBalance;
  final double complianceRate; // 0.0 to 100.0

  const BranchComplianceReport({
    required this.branchId,
    required this.branchName,
    this.state = '',
    this.city = '',
    this.isNational = false,
    required this.memberCount,
    required this.totalExpected,
    required this.totalRemitted,
    required this.outstandingBalance,
    required this.complianceRate,
  });

  String get complianceTier {
    if (complianceRate >= 90.0) return 'Top Performing';
    if (complianceRate >= 70.0) return 'Compliant';
    if (complianceRate >= 40.0) return 'In Arrears';
    return 'Critical Delay';
  }
}
