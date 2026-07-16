import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

/// Persists [AppSettings] to the device local storage.
///
/// This is the only layer allowed to read/write settings from storage,
/// following the repository pattern used across the app.
class SettingsRepository {
  static const String _key = 'app_settings';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
