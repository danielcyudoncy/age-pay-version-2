import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../../core/services/env_service.dart';

class ZegoCallService {
  final FirebaseFirestore _firestore;
  bool _isEngineInitialized = false;

  ZegoCallService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Loads the ZEGOCLOUD AppID from environment (.env). Returns 0 if unset or invalid.
  int get appID {
    final envId = EnvService.zegoAppId;
    if (envId > 0) return envId;
    final raw = dotenv.env['ZEGO_APP_ID']?.trim() ?? '0';
    return int.tryParse(raw) ?? 0;
  }

  /// Loads the ZEGOCLOUD AppSign (64-char key) from environment (.env).
  String get appSign {
    final envSign = EnvService.zegoAppSign;
    if (envSign.isNotEmpty) return envSign;
    return dotenv.env['ZEGO_APP_SIGN']?.trim() ?? '';
  }

  /// Whether valid ZEGOCLOUD credentials have been configured in .env.
  bool get isConfigured {
    return appID > 0 && appSign.isNotEmpty;
  }

  /// Initializes the ZegoExpressEngine singleton with StandardVoiceCall audio scenario.
  Future<void> initEngine() async {
    if (!isConfigured || _isEngineInitialized) return;
    try {
      final profile = ZegoEngineProfile(
        appID,
        ZegoScenario.StandardVoiceCall,
        appSign: appSign,
      );
      await ZegoExpressEngine.createEngineWithProfile(profile);
      _isEngineInitialized = true;
    } catch (e) {
      log('Could not initialize ZegoExpressEngine: $e');
    }
  }

  /// Joins a deterministic audio call room and starts publishing the user's mic stream.
  Future<void> joinCallRoom({
    required String roomId,
    required String userId,
    required String userName,
    Function(String streamId)? onRemoteStreamAdded,
  }) async {
    if (!isConfigured) return;
    try {
      await initEngine();

      // 1. Unmute microphone, enable audio capture device, and route to speaker
      await ZegoExpressEngine.instance.enableAudioCaptureDevice(true);
      await ZegoExpressEngine.instance.muteMicrophone(false);
      await ZegoExpressEngine.instance.muteSpeaker(false);
      await ZegoExpressEngine.instance.enableCamera(false);
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);

      // 2. Set event handlers BEFORE loginRoom so any existing stream in the room is caught immediately
      ZegoExpressEngine.onRoomStreamUpdate =
          (rId, updateType, streamList, extendedData) {
        log('Zego onRoomStreamUpdate: room=$rId, type=$updateType, count=${streamList.length}');
        if (updateType == ZegoUpdateType.Add) {
          for (final stream in streamList) {
            log('Starting playback for remote audio stream: ${stream.streamID}');
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
            onRemoteStreamAdded?.call(stream.streamID);
          }
        } else if (updateType == ZegoUpdateType.Delete) {
          for (final stream in streamList) {
            log('Stopping playback for remote audio stream: ${stream.streamID}');
            ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
          }
        }
      };

      ZegoExpressEngine.onPublisherStateUpdate =
          (streamID, state, errorCode, extendedData) {
        log('Zego onPublisherStateUpdate: stream=$streamID, state=$state, err=$errorCode');
      };

      ZegoExpressEngine.onPlayerStateUpdate =
          (streamID, state, errorCode, extendedData) {
        log('Zego onPlayerStateUpdate: stream=$streamID, state=$state, err=$errorCode');
      };

      // 3. Login to the RTC room
      await ZegoExpressEngine.instance.loginRoom(
        roomId,
        ZegoUser(userId, userName),
      );

      // 4. Publish local microphone audio stream
      final localStreamId = '${roomId}_$userId';
      log('Zego startPublishingStream: $localStreamId');
      await ZegoExpressEngine.instance.startPublishingStream(localStreamId);
      await ZegoExpressEngine.instance.mutePublishStreamAudio(false);
      await ZegoExpressEngine.instance.mutePublishStreamVideo(true);
    } catch (e) {
      log('Could not join ZEGOCLOUD audio room: $e');
    }
  }

  /// Leaves the audio room and cleans up publishing streams.
  Future<void> leaveCallRoom(String roomId) async {
    if (!isConfigured || !_isEngineInitialized) return;
    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
      await ZegoExpressEngine.instance.logoutRoom(roomId);
    } catch (e) {
      log('Could not leave room: $e');
    }
  }

  /// Toggles microphone mute.
  Future<void> setMicrophoneMute(bool isMuted) async {
    if (!isConfigured || !_isEngineInitialized) return;
    try {
      await ZegoExpressEngine.instance.muteMicrophone(isMuted);
      await ZegoExpressEngine.instance.mutePublishStreamAudio(isMuted);
    } catch (e) {
      log('Could not toggle mic mute: $e');
    }
  }

  /// Toggles speakerphone output.
  Future<void> setSpeakerphone(bool isSpeaker) async {
    if (!isConfigured || !_isEngineInitialized) return;
    try {
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(isSpeaker);
    } catch (e) {
      log('Could not route audio: $e');
    }
  }

  /// Destroys the engine on teardown.
  Future<void> destroyEngine() async {
    if (!_isEngineInitialized) return;
    try {
      await ZegoExpressEngine.destroyEngine();
      _isEngineInitialized = false;
    } catch (e) {
      log('Error destroying engine: $e');
    }
  }

  /// Generates a deterministic, unique room ID for a 1-on-1 audio call.
  static String generateRoomId(String orgId, String userA, String userB) {
    final sortedUsers = [userA.trim(), userB.trim()]..sort();
    final cleanOrg = orgId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'call_${cleanOrg}_${sortedUsers[0]}_${sortedUsers[1]}';
  }

  /// Requests microphone permission if not already granted.
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Sends an incoming call alert to the notifications collection
  Future<void> sendCallNotification({
    required String callId,
    required String organizationId,
    required String callerName,
    required String callerRole,
    required String receiverId,
  }) async {
    try {
      final notifDoc = _firestore.collection('notifications').doc();
      await notifDoc.set({
        'id': notifDoc.id,
        'organizationId': organizationId,
        'title': 'Incoming Audio Call',
        'body': '$callerName ($callerRole) is calling you via in-app audio.',
        'type': 'incoming_audio_call',
        'payload': callId,
        'targetUserId': receiverId,
        'read': false,
        'receivedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      log('Could not dispatch call notification: $e');
    }
  }
}
