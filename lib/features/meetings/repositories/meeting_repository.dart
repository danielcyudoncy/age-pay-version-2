import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/meeting_model.dart';
import '../models/meeting_resolution_model.dart';

class MeetingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final String collection = 'meetings';

  MeetingRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<MeetingModel>> getMeetings() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .orderBy('meetingDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MeetingModel.fromFirestore(doc))
                  .toList(),
        )
        .handleError((_) => <MeetingModel>[]);
  }

  Future<MeetingModel?> getMeetingById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) return null;
      return MeetingModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<String> createMeeting({
    required String title,
    String? venue,
    String? organizationId,
    required DateTime meetingDate,
    required String createdBy,
    String targetAudience = 'all',
    String scope = 'branch',
    String? branchId,
  }) async {
    final docRef = _collection.doc();
    final meeting = MeetingModel(
      id: docRef.id,
      organizationId: organizationId ?? '',
      title: title,
      venue: venue ?? '',
      meetingDate: meetingDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      targetAudience: targetAudience,
      scope: scope,
      branchId: branchId,
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

  Future<void> adoptMinutes({
    required String meetingId,
    required String movedBy,
    required String secondedBy,
    String? notes,
  }) async {
    await _collection.doc(meetingId).update({
      'isAdopted': true,
      'adoptedAt': Timestamp.now(),
      'movedBy': movedBy,
      'secondedBy': secondedBy,
      if (notes != null && notes.isNotEmpty) 'adoptionNotes': notes,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> addResolution({
    required String meetingId,
    required MeetingResolutionModel resolution,
  }) async {
    final doc = await _collection.doc(meetingId).get();
    if (!doc.exists) return;
    final meeting = MeetingModel.fromFirestore(doc);
    final updatedResolutions = [...meeting.resolutions, resolution];
    await _collection.doc(meetingId).update({
      'resolutions': updatedResolutions.map((r) => r.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> toggleResolution({
    required String meetingId,
    required String resolutionId,
    required bool isCompleted,
    String? completedBy,
  }) async {
    final doc = await _collection.doc(meetingId).get();
    if (!doc.exists) return;
    final meeting = MeetingModel.fromFirestore(doc);
    final updatedResolutions = meeting.resolutions.map((r) {
      if (r.id == resolutionId) {
        return r.copyWith(
          isCompleted: isCompleted,
          completedAt: isCompleted ? DateTime.now() : null,
          completedBy: isCompleted ? completedBy : null,
        );
      }
      return r;
    }).toList();
    await _collection.doc(meetingId).update({
      'resolutions': updatedResolutions.map((r) => r.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }
}
