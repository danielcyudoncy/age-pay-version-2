import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../main.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../members/models/member_model.dart';
import '../models/call_session_model.dart';
import '../repositories/call_repository.dart';
import '../services/zego_call_service.dart';
import '../views/audio_call_screen.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository();
});

final zegoCallServiceProvider = Provider<ZegoCallService>((ref) {
  return ZegoCallService();
});

/// Streams active incoming calls for the currently authenticated user
final incomingCallsStreamProvider =
    StreamProvider.autoDispose<List<CallSessionModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.uid.isEmpty) return const Stream.empty();
  return ref.watch(callRepositoryProvider).streamIncomingCalls(user.uid);
});

/// Streams the real-time state of a specific active call session
final callSessionStreamProvider =
    StreamProvider.autoDispose.family<CallSessionModel?, String>((ref, callId) {
  return ref.watch(callRepositoryProvider).streamCallSession(callId);
});

final callControllerProvider = Provider<CallController>((ref) {
  return CallController(
    repository: ref.watch(callRepositoryProvider),
    zegoService: ref.watch(zegoCallServiceProvider),
  );
});

class CallController {
  final CallRepository _repository;
  final ZegoCallService _zegoService;

  CallController({
    required CallRepository repository,
    required ZegoCallService zegoService,
  })  : _repository = repository,
        _zegoService = zegoService;

  /// Initiates an in-app audio call to a branch member.
  Future<void> startCall({
    required UserModel caller,
    required MemberModel callee,
    required BuildContext context,
  }) async {
    try {
      // 1. Verify and request microphone permissions
      final hasMic = await _zegoService.requestMicrophonePermission();
      if (!hasMic) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: const Text(
                'Microphone permission is required to place an audio call.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // 2. Callee must have a linked user account to receive in-app audio calls
      final calleeUserId = callee.userId.isNotEmpty ? callee.userId : callee.id;
      if (calleeUserId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This member does not have an active in-app account.'),
            ),
          );
        }
        return;
      }

      // 3. Generate unique call ID for this specific call session
      final orgId = caller.organizationId.isNotEmpty
          ? caller.organizationId
          : 'default_org';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final callId = 'call_${timestamp}_${caller.uid}_$calleeUserId';

      // 4. Create call session model
      final session = CallSessionModel(
        id: callId,
        organizationId: orgId,
        branchId: caller.branchId,
        callerId: caller.uid,
        callerName: caller.displayName.isNotEmpty
            ? caller.displayName
            : 'Executive Member',
        callerRole: caller.role.name,
        receiverId: calleeUserId,
        receiverName: callee.fullName,
        receiverPhone: callee.phoneNumber,
        status: CallStatus.calling,
        callType: 'audio',
        createdAt: DateTime.now(),
      );

      // 5. Save session in Firestore
      await _repository.createCallSession(session);

      // 6. Send in-app notification to receiver
      await _zegoService.sendCallNotification(
        callId: callId,
        organizationId: orgId,
        callerName: session.callerName,
        callerRole: session.callerRole,
        receiverId: calleeUserId,
      );

      // 7. Navigate caller to Audio Call Screen
      final navState = MyApp.navigatorKey.currentState ??
          (context.mounted ? Navigator.of(context, rootNavigator: true) : null);
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => AudioCallScreen(
              callSession: session,
              isCaller: true,
            ),
          ),
        );
      }
    } catch (e) {
      final currentContext = MyApp.navigatorKey.currentContext ?? context;
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Could not start audio call: $e'),
          ),
        );
      }
    }
  }

  /// Accepts an incoming audio call
  Future<void> acceptCall({
    required CallSessionModel session,
    BuildContext? context,
  }) async {
    try {
      final hasMic = await _zegoService.requestMicrophonePermission();
      if (!hasMic) {
        final currentContext = MyApp.navigatorKey.currentContext ?? context;
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: const Text(
                'Microphone permission is required to answer the call.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      await _repository.updateCallStatus(session.id, CallStatus.active);

      final navState = MyApp.navigatorKey.currentState ??
          (context != null && context.mounted
              ? Navigator.of(context, rootNavigator: true)
              : null);
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => AudioCallScreen(
              callSession: session.copyWith(status: CallStatus.active),
              isCaller: false,
            ),
          ),
        );
      }
    } catch (e) {
      final currentContext = MyApp.navigatorKey.currentContext ?? context;
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Could not answer call: $e'),
          ),
        );
      }
    }
  }

  /// Declines an incoming audio call
  Future<void> declineCall(CallSessionModel session) async {
    await _repository.updateCallStatus(session.id, CallStatus.rejected);
  }

  /// Ends an ongoing audio call
  Future<void> endCall(String callId) async {
    await _repository.updateCallStatus(
      callId,
      CallStatus.ended,
      endedAt: DateTime.now(),
    );
  }
}

