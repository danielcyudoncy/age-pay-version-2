import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meeting_rsvp_model.dart';

class MeetingRsvpRepository {
  final FirebaseFirestore _firestore;
  static const String collectionName = 'meeting_rsvps';

  MeetingRsvpRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  String docId(String meetingId, String memberId) => '${meetingId}_$memberId';

  Stream<List<MeetingRsvpModel>> getRsvpsForMeeting(String meetingId) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('meetingId', isEqualTo: meetingId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MeetingRsvpModel.fromFirestore(doc))
                  .toList(),
        )
        .handleError((_) => <MeetingRsvpModel>[]);
  }

  Future<MeetingRsvpModel?> getMemberRsvp(
    String meetingId,
    String memberId,
  ) async {
    final id = docId(meetingId, memberId);
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return MeetingRsvpModel.fromFirestore(doc);
  }

  Future<void> submitRsvp(MeetingRsvpModel rsvp) async {
    final id = docId(rsvp.meetingId, rsvp.memberId);
    final docRef = _collection.doc(id);
    final docSnap = await docRef.get();

    final now = DateTime.now();
    final modelToSave = rsvp.copyWith(
      id: id,
      createdAt: docSnap.exists ? rsvp.createdAt : now,
      updatedAt: now,
    );

    await docRef.set(modelToSave.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteRsvp(String meetingId, String memberId) async {
    final id = docId(meetingId, memberId);
    await _collection.doc(id).delete();
  }
}
