import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service responsible for managing the device's proximity sensor screen-off wake lock.
///
/// When enabled during an active voice call:
/// - Bringing the phone close to the user's ear automatically turns off the screen
///   and disables touch events, preventing accidental ear/cheek interactions.
/// - Moving the phone away from the ear automatically restores the screen backlight and touch.
class ProximitySensorService {
  static const MethodChannel _channel =
      MethodChannel('com.agegrade.cls/proximity');

  bool _isEnabled = false;

  /// Whether proximity monitoring is currently requested/active.
  bool get isEnabled => _isEnabled;

  /// Enables the proximity sensor screen-off wake lock.
  Future<void> enable() async {
    if (_isEnabled) return;
    try {
      await _channel.invokeMethod<bool>('enable');
      _isEnabled = true;
      log('ProximitySensorService: enabled');
    } catch (e) {
      log('ProximitySensorService: enable error: $e');
    }
  }

  /// Disables the proximity sensor screen-off wake lock and restores normal screen behavior.
  Future<void> disable() async {
    if (!_isEnabled) return;
    try {
      await _channel.invokeMethod<bool>('disable');
      _isEnabled = false;
      log('ProximitySensorService: disabled');
    } catch (e) {
      log('ProximitySensorService: disable error: $e');
    }
  }

  /// Checks if proximity screen-off wake lock is supported on this device.
  Future<bool> isSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } catch (e) {
      log('ProximitySensorService: isSupported error: $e');
      return false;
    }
  }
}

/// Riverpod provider for [ProximitySensorService].
final proximitySensorServiceProvider = Provider<ProximitySensorService>((ref) {
  return ProximitySensorService();
});
