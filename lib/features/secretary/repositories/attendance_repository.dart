import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'attendance';

  AttendanceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<AttendanceModel>> getAttendanceForMeeting(String meetingId) {
    return _collection
        .where('meetingId', isEqualTo: meetingId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AttendanceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Stream<List<AttendanceModel>> getAttendanceForMember(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AttendanceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Stream<List<AttendanceModel>> getAttendanceForOrganization(String organizationId) {
    Query query = _collection;
    if (organizationId.isNotEmpty) {
      query = query.where('organizationId', isEqualTo: organizationId);
    }
    return query.snapshots().map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AttendanceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<String> recordAttendance(AttendanceModel attendance) async {
    // Deterministic doc ID ensures a member only has one record per meeting
    final docId = '${attendance.meetingId}_${attendance.memberId}';
    final docRef = _collection.doc(docId);
    final toSave = attendance.copyWith(
      id: docId,
      updatedAt: DateTime.now(),
    );
    await docRef.set(toSave.toFirestore(), SetOptions(merge: true));
    return docId;
  }

  Future<void> updateAttendance(AttendanceModel attendance) async {
    await _collection.doc(attendance.id).update(attendance.toFirestore());
  }

  Future<void> deleteAttendance(String id) async {
    await _collection.doc(id).delete();
  }
}
