import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../national/controllers/national_provider.dart';
import '../models/meeting_model.dart';
import '../repositories/meeting_repository.dart';

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) => MeetingRepository(),
);

final meetingsStreamProvider =
    StreamProvider.autoDispose<List<MeetingModel>>((ref) {
      final user = ref.watch(authProvider).valueOrNull;
      if (user == null) return const Stream.empty();

      final activeScope = ref.watch(activeExecutiveScopeProvider);
      final isNationalScope = activeScope == ExecutiveScope.national &&
          (user.nationalRole != null || user.role == UserRole.superAdmin);

      return ref.watch(meetingRepositoryProvider).getMeetings().map((meetings) {
        if (isNationalScope) {
          // National executives only see national meetings. Branch meetings remain private to the branch.
          return meetings
              .where((m) => m.scope == 'national' || m.branchId == 'national')
              .toList();
        }
        if (user.branchId != null && user.branchId!.isNotEmpty) {
          return meetings
              .where(
                (m) =>
                    m.branchId == user.branchId ||
                    (m.scope == 'national' && m.targetAudience == 'all'),
              )
              .toList();
        }
        if (user.role == UserRole.superAdmin) {
          return meetings;
        }
        // If user has no branch assignment, only show national meetings so branch meetings remain private
        return meetings
            .where((m) => m.scope == 'national' || m.branchId == 'national')
            .toList();
      });
    });

final meetingControllerProvider = Provider<MeetingController>((ref) {
  return MeetingController(ref.watch(meetingRepositoryProvider));
});

class MeetingController {
  final MeetingRepository _repository;

  MeetingController(this._repository);

  Future<String> createMeeting({
    required String title,
    String? venue,
    String? organizationId,
    required DateTime meetingDate,
    required String createdBy,
    String targetAudience = 'all',
    String scope = 'branch',
    String? branchId,
  }) {
    return _repository.createMeeting(
      title: title,
      venue: venue,
      organizationId: organizationId,
      meetingDate: meetingDate,
      createdBy: createdBy,
      targetAudience: targetAudience,
      scope: scope,
      branchId: branchId,
    );
  }

  Future<void> updateMeeting(MeetingModel meeting) {
    return _repository.updateMeeting(meeting);
  }

  Future<void> deleteMeeting(String id) {
    return _repository.deleteMeeting(id);
  }

  Future<Map<String, String>> uploadMinutesFile(
    String meetingId,
    File file,
    String fileName,
  ) {
    return _repository.uploadMinutesFile(meetingId, file, fileName);
  }
}
