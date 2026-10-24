import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../admin/models/branch_model.dart';
import '../models/branch_compliance_report.dart';
import '../repositories/national_repository.dart';

final nationalRepositoryProvider = Provider<NationalRepository>((ref) {
  return NationalRepository();
});

/// Tracks whether a dual-role executive is actively viewing their local Branch or National Body
final activeExecutiveScopeProvider = StateProvider<ExecutiveScope>((ref) {
  return ExecutiveScope.branch;
});

/// Optional levy filter for the branch compliance leaderboard
final selectedLeaderboardLevyIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// Stream of branch compliance reports for a given organization and optional levy
final branchComplianceLeaderboardProvider =
    StreamProvider.family<List<BranchComplianceReport>, String>((ref, organizationId) {
  final selectedLevyId = ref.watch(selectedLeaderboardLevyIdProvider);
  final repo = ref.watch(nationalRepositoryProvider);
  return repo.getBranchComplianceLeaderboard(organizationId, levyId: selectedLevyId);
});

/// Future provider to fetch or ensure the National Branch exists
final nationalBranchProvider =
    FutureProvider.family<BranchModel, String>((ref, organizationId) {
  final repo = ref.watch(nationalRepositoryProvider);
  return repo.ensureNationalBranchExists(organizationId);
});
