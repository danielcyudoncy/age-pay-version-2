import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meeting_model.dart';
import '../repositories/meeting_repository.dart';

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) => MeetingRepository(),
);

final meetingsStreamProvider =
    StreamProvider.autoDispose<List<MeetingModel>>((ref) {
      return ref.watch(meetingRepositoryProvider).getMeetings();
    });

final meetingControllerProvider = Provider<MeetingController>((ref) {
  return MeetingController(ref.watch(meetingRepositoryProvider));
});

class MeetingController {
  final MeetingRepository _repository;

  MeetingController(this._repository);

  Future<String> createMeeting({
    required String title,
    required DateTime meetingDate,
    required String createdBy,
  }) {
    return _repository.createMeeting(
      title: title,
      meetingDate: meetingDate,
      createdBy: createdBy,
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
