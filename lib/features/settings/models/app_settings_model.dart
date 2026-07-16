import 'package:flutter/material.dart';

/// User-configurable preferences for the AgePay application.
///
/// Settings are persisted locally per device via the settings repository.
/// Every field has a sensible default so the app works before any value
/// has been stored.
class AppSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool contributionReminders;
  final bool meetingReminders;
  final bool biometricLock;
  final bool compactView;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.contributionReminders = true,
    this.meetingReminders = true,
    this.biometricLock = false,
    this.compactView = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? contributionReminders,
    bool? meetingReminders,
    bool? biometricLock,
    bool? compactView,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      contributionReminders: contributionReminders ?? this.contributionReminders,
      meetingReminders: meetingReminders ?? this.meetingReminders,
      biometricLock: biometricLock ?? this.biometricLock,
      compactView: compactView ?? this.compactView,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'notificationsEnabled': notificationsEnabled,
      'contributionReminders': contributionReminders,
      'meetingReminders': meetingReminders,
      'biometricLock': biometricLock,
      'compactView': compactView,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values[(json['themeMode'] as int?) ?? 0],
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      contributionReminders: json['contributionReminders'] as bool? ?? true,
      meetingReminders: json['meetingReminders'] as bool? ?? true,
      biometricLock: json['biometricLock'] as bool? ?? false,
      compactView: json['compactView'] as bool? ?? false,
    );
  }
}
