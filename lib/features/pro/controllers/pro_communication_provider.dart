// features/pro/controllers/pro_communication_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pro_communication_service.dart';
import '../../secretary/controllers/announcement_provider.dart';

final proCommunicationServiceProvider = Provider<ProCommunicationService>((ref) {
  return ProCommunicationService(
    announcementRepo: ref.watch(announcementRepositoryProvider),
  );
});
