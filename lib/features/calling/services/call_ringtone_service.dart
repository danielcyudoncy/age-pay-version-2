import 'dart:async';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final callRingtoneServiceProvider = Provider<CallRingtoneService>((ref) {
  final service = CallRingtoneService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Manages ringing audio playback, system alert tones, and haptic vibration feedback
/// for incoming calls and outgoing ringback alerts.
class CallRingtoneService {
  final AudioPlayer _audioPlayer;
  Timer? _ringTimer;
  bool _isPlaying = false;

  /// Default asset path for the in-app incoming call ringtone.
  static const String defaultRingtoneAsset = 'sounds/ringtone.mp3';

  CallRingtoneService({AudioPlayer? audioPlayer})
      : _audioPlayer = audioPlayer ?? AudioPlayer();

  bool get isPlaying => _isPlaying;

  /// Starts repeating ringing alert:
  /// - Plays the custom in-app ringtone audio on loop through the speaker.
  /// - Triggers repeating heavy haptic vibration feedback.
  /// - Gracefully falls back to system alert sound if audio playback encounters an issue.
  Future<void> startRinging({String assetPath = defaultRingtoneAsset}) async {
    if (_isPlaying) return;
    _isPlaying = true;

    // Start periodic haptic vibrations for the ring pulse
    _playVibrationPulse();
    _ringTimer?.cancel();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!_isPlaying) {
        _ringTimer?.cancel();
        return;
      }
      _playVibrationPulse();
    });

    try {
      await _audioPlayer.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.speaker,
          respectSilence: false,
          stayAwake: false,
        ).build(),
      );
      if (!_isPlaying) return;

      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      if (!_isPlaying) return;

      await _audioPlayer.setVolume(1.0);
      if (!_isPlaying) return;

      await _audioPlayer.play(AssetSource(assetPath));
      if (!_isPlaying) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      log('CallRingtoneService: Could not play ringtone asset via AudioPlayer ($e). Using fallback.');
      _playFallbackAlert();
    }
  }

  void _playVibrationPulse() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  void _playFallbackAlert() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// Plays outgoing ringback audio pulses for the caller waiting for the callee to answer.
  void startOutgoingRing() {
    if (_isPlaying) return;
    _isPlaying = true;
    _playOutgoingPulse();
    _ringTimer?.cancel();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!_isPlaying) {
        _ringTimer?.cancel();
        return;
      }
      _playOutgoingPulse();
    });
  }

  void _playOutgoingPulse() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Stops all ringing audio, tones, and vibrations immediately.
  void stop() {
    _isPlaying = false;
    _ringTimer?.cancel();
    _ringTimer = null;
    try {
      _audioPlayer.stop();
    } catch (e) {
      log('CallRingtoneService: error stopping audio: $e');
    }
  }

  /// Cleans up player resources.
  void dispose() {
    stop();
    try {
      _audioPlayer.dispose();
    } catch (_) {}
  }
}
