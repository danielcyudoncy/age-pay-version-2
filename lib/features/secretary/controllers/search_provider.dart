import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';
import '../../meetings/models/meeting_model.dart';
import '../../meetings/repositories/meeting_repository.dart';
import '../../meetings/controllers/meeting_provider.dart';
import '../models/announcement_model.dart';
import '../repositories/announcement_repository.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../controllers/secretary_dashboard_provider.dart';
import 'member_management_provider.dart';

final searchControllerProvider = Provider<SearchController>((ref) {
  return SearchController(
    ref.watch(memberManagementRepositoryProvider),
    ref.watch(meetingRepositoryProvider),
    ref.watch(announcementRepositoryProvider),
    ref.watch(documentRepositoryProvider),
  );
});

class SearchController {
  final MemberRepository _memberRepo;
  final MeetingRepository _meetingRepo;
  final AnnouncementRepository _announcementRepo;
  final DocumentRepository _documentRepo;

  SearchController(this._memberRepo, this._meetingRepo, this._announcementRepo, this._documentRepo);

  Future<List<MemberModel>> searchMembers(String query) => _memberRepo.searchMembers(query);

  Future<List<MeetingModel>> searchMeetings(String query) async {
    final meetings = await _meetingRepo.getMeetings().first;
    final lower = query.toLowerCase();
    return meetings.where((m) => m.title.toLowerCase().contains(lower)).toList();
  }

  Future<List<AnnouncementModel>> searchAnnouncements(String query, String orgId) async {
    final announcements = await _announcementRepo.getAnnouncements(orgId).first;
    final lower = query.toLowerCase();
    return announcements.where((a) => a.title.toLowerCase().contains(lower) || a.body.toLowerCase().contains(lower)).toList();
  }

  Future<List<DocumentModel>> searchDocuments(String query, String orgId) async {
    final documents = await _documentRepo.getDocuments(orgId).first;
    final lower = query.toLowerCase();
    return documents.where((d) => d.title.toLowerCase().contains(lower) || d.description.toLowerCase().contains(lower)).toList();
  }
}
