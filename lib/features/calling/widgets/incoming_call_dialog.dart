import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/call_controller.dart';
import '../models/call_session_model.dart';
import '../services/call_ringtone_service.dart';

class IncomingCallDialog extends ConsumerStatefulWidget {
  final CallSessionModel session;

  const IncomingCallDialog({
    super.key,
    required this.session,
  });

  static Future<bool?> show(BuildContext context, CallSessionModel session) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => IncomingCallDialog(session: session),
    );
  }

  @override
  ConsumerState<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends ConsumerState<IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final CallRingtoneService _ringtoneService;

  @override
  void initState() {
    super.initState();
    _ringtoneService = ref.read(callRingtoneServiceProvider);
    _ringtoneService.startRinging();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  bool _isDismissed = false;

  @override
  void dispose() {
    _isDismissed = true;
    _ringtoneService.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _safeDismiss(bool? result) {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _ringtoneService.stop();
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop(result);
    }
  }

  void _handleAccept() {
    _safeDismiss(true);
  }

  void _handleDecline() {
    _safeDismiss(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If caller hung up or rejected the call, close dialog
    ref.listen<AsyncValue<CallSessionModel?>>(
      callSessionStreamProvider(widget.session.id),
      (previous, next) {
        if (_isDismissed) return;
        final current = next.valueOrNull;
        if (current == null ||
            current.status == CallStatus.ended ||
            current.status == CallStatus.rejected) {
          _safeDismiss(null);
        }
      },
    );

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Ringing Pulse Avatar
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.phone_in_talk,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Incoming Audio Call',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              widget.session.callerName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.session.callerRole.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons: Decline (Red) and Accept (Green)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _handleDecline,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                // Accept
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _handleAccept,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
