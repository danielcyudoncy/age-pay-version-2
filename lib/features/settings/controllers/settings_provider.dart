import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings_model.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

/// Exposes the current [AppSettings] and persists every change.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _repository.load();
  }

  Future<void> _persist(AppSettings next) async {
    state = next;
    await _repository.save(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _persist(state.copyWith(themeMode: mode));

  Future<void> setNotificationsEnabled(bool value) =>
      _persist(state.copyWith(notificationsEnabled: value));

  Future<void> setContributionReminders(bool value) =>
      _persist(state.copyWith(contributionReminders: value));

  Future<void> setMeetingReminders(bool value) =>
      _persist(state.copyWith(meetingReminders: value));

  Future<void> setBiometricLock(bool value) =>
      _persist(state.copyWith(biometricLock: value));

  Future<void> setCompactView(bool value) =>
      _persist(state.copyWith(compactView: value));
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
      final repository = ref.watch(settingsRepositoryProvider);
      return SettingsNotifier(repository);
    });

/// Resolved [ThemeMode] consumed by [MyApp] to theme the whole app.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});
