import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../members/repositories/member_repository.dart';
import '../models/announcement_model.dart';
import '../models/attendance_model.dart';
import '../models/document_model.dart';
import '../models/calendar_event_model.dart';
import '../repositories/announcement_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/document_repository.dart';
import 'calendar_event_provider.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository();
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

final membersStreamProvider = StreamProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(memberRepositoryProvider).getMembers();
});

final announcementsStreamProvider =
    StreamProvider.autoDispose.family<List<AnnouncementModel>, String>((ref, orgId) {
      return ref.watch(announcementRepositoryProvider).getAnnouncements(orgId);
    });

typedef AnnouncementsByDateParams = ({String orgId, DateTime date});

final announcementsByDateStreamProvider = StreamProvider.autoDispose
    .family<List<AnnouncementModel>, AnnouncementsByDateParams>((ref, params) {
      return ref
          .watch(announcementRepositoryProvider)
          .getAnnouncementsForDate(params.orgId, params.date);
    });

final documentsStreamProvider =
    StreamProvider.autoDispose.family<List<DocumentModel>, String>((ref, orgId) {
      return ref.watch(documentRepositoryProvider).getDocuments(orgId);
    });

final calendarEventsStreamProvider =
    StreamProvider.autoDispose.family<List<CalendarEventModel>, String>((ref, orgId) {
      return ref.watch(calendarEventRepositoryProvider).getEvents(orgId);
    });

final attendanceStreamProvider =
    StreamProvider.autoDispose.family<List<AttendanceModel>, String>((ref, meetingId) {
      return ref.watch(attendanceRepositoryProvider).getAttendanceForMeeting(meetingId);
    });
