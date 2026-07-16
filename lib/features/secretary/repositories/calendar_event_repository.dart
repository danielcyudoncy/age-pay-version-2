import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event_model.dart';

class CalendarEventRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'calendar_events';

  CalendarEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<CalendarEventModel>> getEvents(String organizationId) {
    return _collection
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CalendarEventModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<String> createEvent(CalendarEventModel event) async {
    final docRef = _collection.doc();
    await docRef.set(event.toFirestore());
    return docRef.id;
  }

  Future<void> updateEvent(CalendarEventModel event) async {
    await _collection
        .doc(event.id)
        .update(event.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> deleteEvent(String id) async {
    await _collection.doc(id).delete();
  }
}
