import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final attendanceControllerProvider = Provider<AttendanceController>((ref) {
  return AttendanceController(ref.watch(attendanceRepositoryProvider));
});

class AttendanceController {
  final AttendanceRepository _repository;
  AttendanceController(this._repository);

  Future<String> recordAttendance(AttendanceModel attendance) {
    return _repository.recordAttendance(attendance);
  }

  Future<void> updateAttendance(AttendanceModel attendance) {
    return _repository.updateAttendance(attendance);
  }

  Future<void> deleteAttendance(String id) {
    return _repository.deleteAttendance(id);
  }
}
