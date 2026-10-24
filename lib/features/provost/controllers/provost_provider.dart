import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../meetings/controllers/meeting_provider.dart';
import '../../meetings/models/meeting_model.dart';
import '../../obligations/models/obligation_model.dart';
import '../models/penalty_waiver_model.dart';
import '../repositories/provost_repository.dart';

final provostRepositoryProvider = Provider<ProvostRepository>((ref) {
  return ProvostRepository();
});

final provostPenaltiesStreamProvider =
    StreamProvider.autoDispose.family<List<ObligationModel>, String>((ref, orgId) {
  return ref.watch(provostRepositoryProvider).getProvostPenalties(orgId);
});

final provostWaiversStreamProvider =
    StreamProvider.autoDispose.family<List<PenaltyWaiverModel>, String>((ref, orgId) {
  return ref.watch(provostRepositoryProvider).getWaivers(orgId);
});

final pendingWaiversStreamProvider =
    StreamProvider.autoDispose.family<List<PenaltyWaiverModel>, String>((ref, orgId) {
  return ref.watch(provostRepositoryProvider).getPendingWaivers(orgId);
});

/// Identifies if there is an active meeting today for decorum enforcement.
final activeMeetingProvider =
    Provider.autoDispose.family<MeetingModel?, String>((ref, orgId) {
  final meetingsAsync = ref.watch(meetingsStreamProvider);
  final meetings = meetingsAsync.valueOrNull ?? [];
  final now = DateTime.now();

  // Find meeting happening today in the organization
  for (final m in meetings) {
    if (m.organizationId.isNotEmpty && m.organizationId != orgId) continue;
    final isToday = m.meetingDate.year == now.year &&
        m.meetingDate.month == now.month &&
        m.meetingDate.day == now.day;
    if (isToday) return m;
  }

  // If none today, return null
  return null;
});

final provostControllerProvider = Provider<ProvostController>((ref) {
  return ProvostController(ref.watch(provostRepositoryProvider));
});

class ProvostController {
  final ProvostRepository _repository;

  ProvostController(this._repository);

  Future<String> issuePenalty({
    required String organizationId,
    required String memberId,
    required String memberName,
    required PenaltyInfractionType infractionType,
    required String title,
    required String description,
    required double amount,
    required String issuedBy,
    String? meetingId,
    DateTime? dueDate,
  }) {
    return _repository.issuePenalty(
      organizationId: organizationId,
      memberId: memberId,
      memberName: memberName,
      infractionType: infractionType,
      title: title,
      description: description,
      amount: amount,
      issuedBy: issuedBy,
      meetingId: meetingId,
      dueDate: dueDate,
    );
  }

  Future<String> requestPenaltyWaiver({
    required String organizationId,
    required String obligationId,
    required String memberId,
    required String memberName,
    required String penaltyTitle,
    required double amount,
    required PenaltyInfractionType infractionType,
    required String reason,
    required String requestedBy,
  }) {
    return _repository.requestPenaltyWaiver(
      organizationId: organizationId,
      obligationId: obligationId,
      memberId: memberId,
      memberName: memberName,
      penaltyTitle: penaltyTitle,
      amount: amount,
      infractionType: infractionType,
      reason: reason,
      requestedBy: requestedBy,
    );
  }

  Future<void> approvePenaltyWaiver({
    required String waiverId,
    required String obligationId,
    required String reviewedBy,
  }) {
    return _repository.approvePenaltyWaiver(
      waiverId: waiverId,
      obligationId: obligationId,
      reviewedBy: reviewedBy,
    );
  }

  Future<void> rejectPenaltyWaiver({
    required String waiverId,
    required String obligationId,
    required String reviewedBy,
    required String rejectionReason,
  }) {
    return _repository.rejectPenaltyWaiver(
      waiverId: waiverId,
      obligationId: obligationId,
      reviewedBy: reviewedBy,
      rejectionReason: rejectionReason,
    );
  }
}
