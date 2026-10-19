import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meeting_rsvp_model.dart';
import '../repositories/meeting_rsvp_repository.dart';

final meetingRsvpRepositoryProvider = Provider<MeetingRsvpRepository>(
  (ref) => MeetingRsvpRepository(),
);

final meetingRsvpsStreamProvider =
    StreamProvider.autoDispose.family<List<MeetingRsvpModel>, String>((
      ref,
      meetingId,
    ) {
      final repository = ref.watch(meetingRsvpRepositoryProvider);
      return repository.getRsvpsForMeeting(meetingId);
    });

/// Provider for a specific member's RSVP for a given meeting
final memberMeetingRsvpProvider =
    Provider.autoDispose.family<MeetingRsvpModel?, ({String meetingId, String memberId})>((
      ref,
      params,
    ) {
      final rsvpsAsync = ref.watch(meetingRsvpsStreamProvider(params.meetingId));
      return rsvpsAsync.when(
        data: (rsvps) {
          final matches = rsvps.where((r) => r.memberId == params.memberId);
          return matches.isNotEmpty ? matches.first : null;
        },
        loading: () => null,
        error: (_, _) => null,
      );
    });

final meetingRsvpControllerProvider = Provider<MeetingRsvpController>((ref) {
  return MeetingRsvpController(ref.watch(meetingRsvpRepositoryProvider));
});

class MeetingRsvpController {
  final MeetingRsvpRepository _repository;

  MeetingRsvpController(this._repository);

  Future<void> submitRsvp({
    required String meetingId,
    required String memberId,
    required String memberName,
    required String organizationId,
    required MeetingRsvpStatus status,
    String? reason,
  }) async {
    final now = DateTime.now();
    final rsvp = MeetingRsvpModel(
      id: _repository.docId(meetingId, memberId),
      organizationId: organizationId,
      meetingId: meetingId,
      memberId: memberId,
      memberName: memberName,
      status: status,
      reason: reason?.trim() ?? '',
      createdAt: now,
      updatedAt: now,
      createdBy: memberId,
    );

    await _repository.submitRsvp(rsvp);
  }

  Future<void> deleteRsvp(String meetingId, String memberId) async {
    await _repository.deleteRsvp(meetingId, memberId);
  }
}
