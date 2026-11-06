import 'organization_model.dart';

class AdminDashboardData {
  final int totalOrganizations;
  final int totalUsers;
  final int activeOrganizations;
  final int pendingApprovals;
  final double totalCollections;
  final int totalPaymentsCount;
  final List<OrganizationModel> recentOrganizations;

  const AdminDashboardData({
    this.totalOrganizations = 0,
    this.totalUsers = 0,
    this.activeOrganizations = 0,
    this.pendingApprovals = 0,
    this.totalCollections = 0.0,
    this.totalPaymentsCount = 0,
    this.recentOrganizations = const [],
  });
}
