import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../meetings/controllers/meeting_provider.dart';
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

final allCalendarEventsProvider =
    Provider.autoDispose.family<AsyncValue<List<CalendarEventModel>>, String>((ref, orgId) {
      final eventsAsync = ref.watch(calendarEventsStreamProvider(orgId));
      final announcementsAsync = ref.watch(announcementsStreamProvider(orgId));
      final meetingsAsync = ref.watch(meetingsStreamProvider);

      if (eventsAsync.isLoading &&
          !eventsAsync.hasValue &&
          !announcementsAsync.hasValue &&
          !meetingsAsync.hasValue) {
        return const AsyncValue.loading();
      }

      if (eventsAsync.hasError &&
          !eventsAsync.hasValue &&
          !announcementsAsync.hasValue &&
          !meetingsAsync.hasValue) {
        return AsyncValue.error(
          eventsAsync.error!,
          eventsAsync.stackTrace ?? StackTrace.current,
        );
      }

      final calendarEvents = eventsAsync.valueOrNull ?? [];
      final announcements = announcementsAsync.valueOrNull ?? [];
      final meetings = meetingsAsync.valueOrNull ?? [];

      final List<CalendarEventModel> combined = List.from(calendarEvents);
      final Set<String> existingKeys = {
        for (final e in calendarEvents)
          '${DateFormat('yyyy-MM-dd').format(e.startDate)}_${e.title.trim().toLowerCase()}',
      };

      for (final a in announcements) {
        final date = a.announcementDate ?? (a.isScheduled ? a.scheduledAt : null);
        if (date != null) {
          final key = '${DateFormat('yyyy-MM-dd').format(date)}_${a.title.trim().toLowerCase()}';
          if (!existingKeys.contains(key)) {
            existingKeys.add(key);
            CalendarEventType type = CalendarEventType.reminder;
            if (a.category == AnnouncementCategory.meeting) {
              type = CalendarEventType.meeting;
            } else if (a.category == AnnouncementCategory.contribution ||
                a.category == AnnouncementCategory.financialNotice) {
              type = CalendarEventType.contributionDeadline;
            } else if (a.category == AnnouncementCategory.event ||
                a.category == AnnouncementCategory.election) {
              type = CalendarEventType.communityEvent;
            }

            combined.add(
              CalendarEventModel(
                id: 'announcement_${a.id}',
                organizationId: a.organizationId.isNotEmpty ? a.organizationId : orgId,
                title: a.title,
                description: a.body,
                type: type,
                startDate: date,
                endDate: date.add(const Duration(hours: 1)),
                allDay: false,
                location: null,
                createdBy: a.createdBy,
                createdAt: a.createdAt,
                updatedAt: a.updatedAt,
              ),
            );
          }
        }
      }

      for (final m in meetings) {
        if (orgId.isEmpty || m.organizationId.isEmpty || m.organizationId == orgId) {
          final key = '${DateFormat('yyyy-MM-dd').format(m.meetingDate)}_${m.title.trim().toLowerCase()}';
          if (!existingKeys.contains(key)) {
            existingKeys.add(key);
            combined.add(
              CalendarEventModel(
                id: 'meeting_${m.id}',
                organizationId: m.organizationId.isNotEmpty ? m.organizationId : orgId,
                title: m.title,
                description: m.venue.isNotEmpty ? m.venue : 'Meeting Session',
                type: CalendarEventType.meeting,
                startDate: m.meetingDate,
                endDate: m.meetingDate.add(const Duration(hours: 1)),
                allDay: false,
                location: m.venue.isNotEmpty ? m.venue : null,
                createdBy: m.createdBy,
                createdAt: m.createdAt,
                updatedAt: m.updatedAt,
              ),
            );
          }
        }
      }

      combined.sort((a, b) => a.startDate.compareTo(b.startDate));
      return AsyncValue.data(combined);
    });

final attendanceStreamProvider =
    StreamProvider.autoDispose.family<List<AttendanceModel>, String>((ref, meetingId) {
      return ref.watch(attendanceRepositoryProvider).getAttendanceForMeeting(meetingId);
    });
