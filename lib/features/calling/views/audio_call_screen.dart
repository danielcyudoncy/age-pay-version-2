import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../dashboard/views/home_router.dart';
import '../controllers/call_controller.dart';
import '../models/call_session_model.dart';
import '../services/call_ringtone_service.dart';
import '../services/proximity_sensor_service.dart';
import '../services/zego_call_service.dart';

class AudioCallScreen extends ConsumerStatefulWidget {
  final CallSessionModel callSession;
  final bool isCaller;

  const AudioCallScreen({
    super.key,
    required this.callSession,
    this.isCaller = false,
  });

  @override
  ConsumerState<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends ConsumerState<AudioCallScreen> {
  Timer? _callDurationTimer;
  int _secondsElapsed = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  late bool _isConnecting;
  bool _isPopping = false;

  late final ZegoCallService _zegoService;
  late final CallRingtoneService _ringtoneService;
  late final ProximitySensorService _proximityService;

  @override
  void initState() {
    super.initState();
    _zegoService = ref.read(zegoCallServiceProvider);
    _ringtoneService = ref.read(callRingtoneServiceProvider);
    _proximityService = ref.read(proximitySensorServiceProvider);

    // Enable proximity sensor screen-off wake lock during active audio call
    _proximityService.enable();

    // Caller waits for receiver to accept; receiver is already active
    _isConnecting = widget.isCaller &&
        widget.callSession.status == CallStatus.calling;

    if (widget.isCaller && _isConnecting) {
      _ringtoneService.startOutgoingRing();
    }

    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          if (!_isConnecting) {
            _secondsElapsed++;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initZegoAudio();
    });
  }

  Future<void> _initZegoAudio() async {
    final user = ref.read(authProvider).valueOrNull;
    if (!_zegoService.isConfigured) return;

    final roomId = ZegoCallService.generateRoomId(
      widget.callSession.organizationId,
      widget.callSession.callerId,
      widget.callSession.receiverId,
    );

    await _zegoService.joinCallRoom(
      roomId: roomId,
      userId: user?.uid ?? 'user_guest',
      userName: user?.displayName.isNotEmpty == true
          ? user!.displayName
          : 'Member',
      onRemoteStreamAdded: (streamId) {
        // Stop outgoing ringback as soon as remote audio stream connects
        if (mounted && _isConnecting) {
          _ringtoneService.stop();
          setState(() {
            _isConnecting = false;
          });
        }
      },
    );
  }

  void _safePop([String? message]) {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    _proximityService.disable();
    _ringtoneService.stop();
    _callDurationTimer?.cancel();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeRouter()),
      );
    }
  }

  @override
  void dispose() {
    _proximityService.disable();
    _callDurationTimer?.cancel();
    _ringtoneService.stop();
    final roomId = ZegoCallService.generateRoomId(
      widget.callSession.organizationId,
      widget.callSession.callerId,
      widget.callSession.receiverId,
    );
    _zegoService.leaveCallRoom(roomId);
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _hangUp() async {
    _proximityService.disable();
    _ringtoneService.stop();
    _callDurationTimer?.cancel();
    await ref.read(callControllerProvider).endCall(widget.callSession.id);
    _safePop();
  }

  @override
  Widget build(BuildContext context) {
    final zegoService = ref.watch(zegoCallServiceProvider);

    final remoteName = widget.isCaller
        ? widget.callSession.receiverName
        : widget.callSession.callerName;
    final remoteRole =
        widget.isCaller ? 'Member' : widget.callSession.callerRole;

    // Listen to real-time session status; if accepted by callee or ended/rejected
    ref.listen<AsyncValue<CallSessionModel?>>(
      callSessionStreamProvider(widget.callSession.id),
      (previous, next) {
        final session = next.valueOrNull;
        if (session != null) {
          if (session.status == CallStatus.active && _isConnecting) {
            _ringtoneService.stop();
            if (mounted) {
              setState(() {
                _isConnecting = false;
              });
            }
          } else if (session.status == CallStatus.ended ||
              session.status == CallStatus.rejected) {
            _safePop(
              session.status == CallStatus.rejected
                  ? 'Call declined.'
                  : 'Call ended.',
            );
          }
        }
      },
    );

    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _hangUp();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E242B),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'End Call',
              onPressed: _hangUp,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          const Spacer(),

                // Active Avatar / Pulsing Calling Indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        remoteName.isNotEmpty
                            ? remoteName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  remoteName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                Text(
                  remoteRole.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                // Status Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isConnecting ? Colors.amber : Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnecting
                            ? (widget.isCaller ? 'Ringing...' : 'Connecting...')
                            : _formatDuration(_secondsElapsed),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!zegoService.isConfigured) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.shade400.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      '⚡ Audio Simulation Active (Set ZEGO_APP_ID & ZEGO_APP_SIGN in .env for live audio streaming)',
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Control Buttons: Mute, Speaker, Hangup
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: _isMuted
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.15),
                            foregroundColor:
                                _isMuted ? Colors.black : Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                          icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                          onPressed: () async {
                            final newMute = !_isMuted;
                            setState(() => _isMuted = newMute);
                            await zegoService.setMicrophoneMute(newMute);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isMuted ? 'Muted' : 'Mute',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // End Call (Hangup) Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filled(
                          iconSize: 34,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(18),
                          ),
                          icon: const Icon(Icons.call_end),
                          onPressed: _hangUp,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'End',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),

                    // Speaker Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: _isSpeakerOn
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.15),
                            foregroundColor:
                                _isSpeakerOn ? Colors.black : Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                          icon: Icon(
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                          ),
                          onPressed: () async {
                            final newSpeaker = !_isSpeakerOn;
                            setState(() => _isSpeakerOn = newSpeaker);
                            await zegoService.setSpeakerphone(newSpeaker);
                            if (newSpeaker) {
                              await _proximityService.disable();
                            } else {
                              await _proximityService.enable();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSpeakerOn ? 'Speaker' : 'Earpiece',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  },
),
),
),
);
}
}
