import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event_model.dart';
import '../repositories/calendar_event_repository.dart';

final calendarEventRepositoryProvider = Provider<CalendarEventRepository>((ref) {
  return CalendarEventRepository();
});

final calendarEventControllerProvider = Provider<CalendarEventController>((ref) {
  return CalendarEventController(ref.watch(calendarEventRepositoryProvider));
});

class CalendarEventController {
  final CalendarEventRepository _repository;
  CalendarEventController(this._repository);

  Future<String> createEvent(CalendarEventModel event) {
    return _repository.createEvent(event);
  }

  Future<void> updateEvent(CalendarEventModel event) {
    return _repository.updateEvent(event);
  }

  Future<void> deleteEvent(String id) {
    return _repository.deleteEvent(id);
  }
}
