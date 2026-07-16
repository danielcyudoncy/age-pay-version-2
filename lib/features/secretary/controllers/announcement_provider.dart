import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement_model.dart';
import '../repositories/announcement_repository.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

final announcementControllerProvider = Provider<AnnouncementController>((ref) {
  return AnnouncementController(ref.watch(announcementRepositoryProvider));
});

class AnnouncementController {
  final AnnouncementRepository _repository;
  AnnouncementController(this._repository);

  Future<String> createAnnouncement(AnnouncementModel announcement) {
    return _repository.createAnnouncement(announcement);
  }

  Future<void> updateAnnouncement(AnnouncementModel announcement) {
    return _repository.updateAnnouncement(announcement);
  }

  Future<void> deleteAnnouncement(String id) {
    return _repository.deleteAnnouncement(id);
  }
}
