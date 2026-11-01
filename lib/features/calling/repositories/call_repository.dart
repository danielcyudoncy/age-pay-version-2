import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/call_session_model.dart';

class CallRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'calls';

  CallRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  /// Creates a new call session document
  Future<void> createCallSession(CallSessionModel session) async {
    await _collection.doc(session.id).set(session.toFirestore());
  }

  /// Streams active incoming calls directed to the given receiver UID
  Stream<List<CallSessionModel>> streamIncomingCalls(String receiverId) {
    if (FirebaseAuth.instance.currentUser == null || receiverId.isEmpty) {
      return const Stream.empty();
    }
    return _collection
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: CallStatus.calling.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CallSessionModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <CallSessionModel>[]);
  }

  /// Streams the status of a specific call session (for caller to detect acceptance/decline)
  Stream<CallSessionModel?> streamCallSession(String callId) {
    if (callId.isEmpty) return Stream.value(null);
    return _collection.doc(callId).snapshots().map((doc) {
      if (doc.exists) {
        return CallSessionModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Updates call status (e.g. accepted, rejected, ended)
  Future<void> updateCallStatus(
    String callId,
    CallStatus status, {
    DateTime? endedAt,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == CallStatus.ended || status == CallStatus.rejected) {
      updates['endedAt'] = Timestamp.fromDate(endedAt ?? DateTime.now());
    }
    await _collection.doc(callId).update(updates);
  }

  /// Retrieves a specific call session
  Future<CallSessionModel?> getCallSession(String callId) async {
    final doc = await _collection.doc(callId).get();
    if (doc.exists) {
      return CallSessionModel.fromFirestore(doc);
    }
    return null;
  }
}

