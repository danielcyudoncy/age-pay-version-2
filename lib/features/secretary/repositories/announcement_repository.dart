import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement_model.dart';

class AnnouncementRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'announcements';

  AnnouncementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<AnnouncementModel>> getAnnouncements(String organizationId) {
    return _collection
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AnnouncementModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<String> createAnnouncement(AnnouncementModel announcement) async {
    final docRef = _collection.doc();
    await docRef.set(announcement.toFirestore());
    return docRef.id;
  }

  Future<void> updateAnnouncement(AnnouncementModel announcement) async {
    await _collection
        .doc(announcement.id)
        .update(announcement.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> deleteAnnouncement(String id) async {
    await _collection.doc(id).delete();
  }
}
