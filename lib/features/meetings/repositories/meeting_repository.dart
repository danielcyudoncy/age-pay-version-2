import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/meeting_model.dart';

class MeetingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final String collection = 'meetings';

  MeetingRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<MeetingModel>> getMeetings() {
    return _collection
        .orderBy('meetingDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MeetingModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<String> createMeeting({
    required String title,
    required DateTime meetingDate,
    required String createdBy,
  }) async {
    final docRef = _collection.doc();
    final meeting = MeetingModel(
      id: docRef.id,
      title: title,
      meetingDate: meetingDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
    await docRef.set(meeting.toFirestore());
    return docRef.id;
  }

  Future<void> updateMeeting(MeetingModel meeting) async {
    await _collection
        .doc(meeting.id)
        .update(meeting.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> deleteMeeting(String id) async {
    await _collection.doc(id).delete();
    await _storage.ref().child('meetings/$id').listAll().then((result) async {
      for (final item in result.items) {
        await item.delete();
      }
    });
  }

  Future<Map<String, String>> uploadMinutesFile(
    String meetingId,
    File file,
    String fileName,
  ) async {
    final ref = _storage.ref().child('meetings/$meetingId/$fileName');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return {'url': url, 'name': fileName};
  }
}
