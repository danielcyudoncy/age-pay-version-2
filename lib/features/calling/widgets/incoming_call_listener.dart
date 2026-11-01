import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../notifications/services/notification_service.dart';
import '../controllers/call_controller.dart';
import '../models/call_session_model.dart';
import 'incoming_call_dialog.dart';

/// Wraps any screen/router and listens for incoming real-time audio calls.
/// Automatically triggers ringing alerts and pops up the [IncomingCallDialog]
/// when an incoming call starts ringing.
class IncomingCallListener extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingCallListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  String? _currentlyShowingCallId;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<CallSessionModel>>>(
      incomingCallsStreamProvider,
      (previous, next) {
        final calls = next.valueOrNull ?? const [];
        CallSessionModel? ringingCall;
        for (final call in calls) {
          if (call.status == CallStatus.calling) {
            ringingCall = call;
            break;
          }
        }

        if (ringingCall != null && _currentlyShowingCallId != ringingCall.id) {
          _currentlyShowingCallId = ringingCall.id;
          _handleIncomingCall(ringingCall);
        }
      },
    );

    return widget.child;
  }

  Future<void> _handleIncomingCall(CallSessionModel call) async {
    final dialogContext = MyApp.navigatorKey.currentContext ?? context;
    final notifService = NotificationService();
    notifService.showCallNotification(
      callId: call.id,
      callerName: call.callerName,
      callerRole: call.callerRole,
    );

    final accepted = await IncomingCallDialog.show(dialogContext, call);

    await notifService.cancelCallNotification(call.id);

    if (!mounted) return;
    if (_currentlyShowingCallId == call.id) {
      _currentlyShowingCallId = null;
    }
    if (accepted == true) {
      await ref.read(callControllerProvider).acceptCall(
            session: call,
          );
    } else if (accepted == false) {
      await ref.read(callControllerProvider).declineCall(call);
    }
  }
}
