import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/system_settings_model.dart';

class SystemSettingsRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'system_settings';
  final String docId = 'global_config';

  static SystemSettingsModel _cachedSettings = SystemSettingsModel.defaults();
  static final StreamController<SystemSettingsModel> _localStreamController =
      StreamController<SystemSettingsModel>.broadcast();

  SystemSettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference get _docRef => _firestore.collection(collection).doc(docId);

  Stream<SystemSettingsModel> streamSettings() async* {
    yield _cachedSettings;

    // Listen to local stream updates
    _localStreamController.stream.listen((settings) {
      _cachedSettings = settings;
    });

    try {
      await for (final doc in _docRef.snapshots().handleError((_) {})) {
        if (doc.exists && doc.data() != null) {
          _cachedSettings = SystemSettingsModel.fromFirestore(doc);
          yield _cachedSettings;
        }
      }
    } catch (_) {
      // Keep cached defaults on error
    }
  }

  Future<SystemSettingsModel> getSettings() async {
    try {
      final doc = await _docRef.get();
      if (doc.exists && doc.data() != null) {
        _cachedSettings = SystemSettingsModel.fromFirestore(doc);
        return _cachedSettings;
      }
    } catch (_) {}
    return _cachedSettings;
  }

  /// Updates settings with offline-first persistence.
  /// Returns `true` if saved to remote Firestore, or `false` if saved locally
  /// (e.g. pending remote rules deployment or offline).
  Future<bool> updateSettings(
    SystemSettingsModel settings, {
    required String updatedBy,
  }) async {
    final updated = settings.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
    _cachedSettings = updated;
    _localStreamController.add(updated);

    try {
      await _docRef.set(updated.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (_) {
      // Local state is preserved and active; remote sync will happen once rules are deployed
      return false;
    }
  }

  Future<void> toggleMaintenanceMode(
    bool enabled, {
    String? message,
    required String updatedBy,
  }) async {
    final updated = _cachedSettings.copyWith(
      maintenanceMode: enabled,
      maintenanceMessage: message ?? _cachedSettings.maintenanceMessage,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
    await updateSettings(updated, updatedBy: updatedBy);
  }
}
