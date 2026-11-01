import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/calling/models/call_session_model.dart';
import 'package:cls/features/calling/services/call_ringtone_service.dart';
import 'package:cls/features/calling/services/proximity_sensor_service.dart';
import 'package:cls/features/calling/services/zego_call_service.dart';
import 'package:flutter/services.dart';
import 'package:cls/features/calling/widgets/member_call_button.dart';
import 'package:cls/features/calling/views/branch_directory_screen.dart';
import 'package:cls/features/calling/widgets/incoming_call_dialog.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/auth/services/auth_service.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/core/constants/enums.dart';

class _MockAuthService implements AuthService {
  final UserModel? user;
  _MockAuthService(this.user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CallSessionModel Tests', () {
    final now = DateTime(2026, 11, 1, 12, 0, 0);

    test('instantiates with correct default values', () {
      final session = CallSessionModel(
        id: 'call_123',
        organizationId: 'org_abc',
        callerId: 'user_1',
        callerName: 'Alice Caller',
        callerRole: 'Member',
        receiverId: 'user_2',
        receiverName: 'Bob Callee',
        createdAt: now,
      );

      expect(session.id, 'call_123');
      expect(session.organizationId, 'org_abc');
      expect(session.status, CallStatus.calling);
      expect(session.callType, 'audio');
      expect(session.callerName, 'Alice Caller');
      expect(session.receiverName, 'Bob Callee');
    });

    test('toFirestore includes all expected fields', () {
      final session = CallSessionModel(
        id: 'call_456',
        organizationId: 'org_xyz',
        branchId: 'branch_east',
        callerId: 'user_1',
        callerName: 'Alice',
        callerRole: 'treasurer',
        receiverId: 'user_2',
        receiverName: 'Bob',
        receiverPhone: '+2348000000000',
        status: CallStatus.active,
        createdAt: now,
      );

      final map = session.toFirestore();

      expect(map['id'], 'call_456');
      expect(map['organizationId'], 'org_xyz');
      expect(map['branchId'], 'branch_east');
      expect(map['callerId'], 'user_1');
      expect(map['receiverPhone'], '+2348000000000');
      expect(map['status'], 'active');
      expect(map['callType'], 'audio');
    });

    test('copyWith updates specified fields correctly', () {
      final session = CallSessionModel(
        id: 'call_789',
        organizationId: 'org_test',
        callerId: 'u1',
        callerName: 'Name1',
        callerRole: 'member',
        receiverId: 'u2',
        receiverName: 'Name2',
        createdAt: now,
      );

      final ended = session.copyWith(
        status: CallStatus.ended,
        endedAt: now.add(const Duration(minutes: 5)),
      );

      expect(ended.id, 'call_789');
      expect(ended.status, CallStatus.ended);
      expect(ended.endedAt, now.add(const Duration(minutes: 5)));
      expect(session.status, CallStatus.calling); // immutability verified
    });
  });

  group('ZegoCallService Room ID Generation Tests', () {
    test('generateRoomId is deterministic regardless of caller/callee order', () {
      final room1 = ZegoCallService.generateRoomId('org_1', 'userA', 'userB');
      final room2 = ZegoCallService.generateRoomId('org_1', 'userB', 'userA');

      expect(room1, equals(room2));
      expect(room1, 'call_org_1_userA_userB');
    });

    test('generateRoomId sanitizes special characters in organization ID', () {
      final room = ZegoCallService.generateRoomId('org-2026/alpha!', 'user1', 'user2');
      expect(room, 'call_org_2026_alpha__user1_user2');
    });
  });

  group('MemberCallButton Widget Tests', () {
    final callerUser = UserModel(
      uid: 'user_caller',
      email: 'caller@example.com',
      displayName: 'Caller Name',
      phoneNumber: '+2348000000000',
      role: UserRole.member,
      branchId: 'branch_1',
      organizationId: 'org_test',
      status: AccountStatus.approved,
      createdAt: DateTime.now(),
    );

    final fellowMember = MemberModel(
      id: 'member_2',
      userId: 'user_callee',
      fullName: 'Fellow Member',
      email: 'callee@example.com',
      phoneNumber: '+2348012345678',
      branchId: 'branch_1',
      dateOfBirth: DateTime(1990),
      joinedDate: DateTime(2020),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final selfMember = MemberModel(
      id: 'member_1',
      userId: 'user_caller',
      fullName: 'Self Member',
      email: 'caller@example.com',
      phoneNumber: '+2348000000000',
      branchId: 'branch_1',
      dateOfBirth: DateTime(1990),
      joinedDate: DateTime(2020),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('does not render when member is current user (self)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(_MockAuthService(callerUser));
              notifier.state = AsyncValue.data(callerUser);
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberCallButton(member: selfMember),
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('renders call button when member is another branch member', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(_MockAuthService(callerUser));
              notifier.state = AsyncValue.data(callerUser);
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberCallButton(member: fellowMember),
            ),
          ),
        ),
      );

      expect(find.text('Call'), findsOneWidget);
      expect(find.byIcon(Icons.phone_in_talk), findsOneWidget);
    });

    testWidgets('renders compact IconButton when isCompact is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(_MockAuthService(callerUser));
              notifier.state = AsyncValue.data(callerUser);
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberCallButton(member: fellowMember, isCompact: true),
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.phone_in_talk), findsOneWidget);
    });
  });

  group('BranchDirectoryScreen Tests', () {
    final callerUser = UserModel(
      uid: 'user_caller',
      email: 'caller@example.com',
      displayName: 'Alice Caller',
      phoneNumber: '+2348011111111',
      role: UserRole.member,
      branchId: 'branch_1',
      organizationId: 'org_test',
      status: AccountStatus.approved,
      createdAt: DateTime.now(),
    );

    final membersList = [
      MemberModel(
        id: 'm1',
        userId: 'user_caller',
        fullName: 'Alice Caller',
        email: 'alice@test.com',
        phoneNumber: '+2348011111111',
        branchId: 'branch_1',
        dateOfBirth: DateTime(1990),
        joinedDate: DateTime(2020),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'm2',
        userId: 'u2',
        fullName: 'Chidi Okonkwo',
        email: 'chidi@test.com',
        phoneNumber: '+2348022222222',
        branchId: 'branch_1',
        dateOfBirth: DateTime(1992),
        joinedDate: DateTime(2021),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MemberModel(
        id: 'm3',
        userId: 'u3',
        fullName: 'Emeka Eze',
        email: 'emeka@test.com',
        phoneNumber: '+2348033333333',
        branchId: 'branch_1',
        dateOfBirth: DateTime(1988),
        joinedDate: DateTime(2019),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    testWidgets('renders search field and filters members in real-time', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(_MockAuthService(callerUser));
              notifier.state = AsyncValue.data(callerUser);
              return notifier;
            }),
            branchMembersStreamProvider.overrideWith(
              (ref) => Stream.value(membersList),
            ),
          ],
          child: const MaterialApp(
            home: BranchDirectoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify directory title and members rendered
      expect(find.text('Branch Directory'), findsOneWidget);
      expect(find.text('Chidi Okonkwo'), findsOneWidget);
      expect(find.text('Emeka Eze'), findsOneWidget);

      // Filter by typing 'Chidi' in search field
      await tester.enterText(find.byType(TextField), 'Chidi');
      await tester.pumpAndSettle();

      expect(find.text('Chidi Okonkwo'), findsOneWidget);
      expect(find.text('Emeka Eze'), findsNothing);
    });
  });

  group('IncomingCallDialog Widget Tests', () {
    final testSession = CallSessionModel(
      id: 'call_test_dialog',
      organizationId: 'org_test',
      callerId: 'caller_123',
      callerName: 'Ngozi Adebayo',
      callerRole: 'Treasurer',
      receiverId: 'receiver_456',
      receiverName: 'Chidi Okonkwo',
      createdAt: DateTime(2026, 11, 1),
    );

    testWidgets('renders caller name, role, decline, and accept buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => IncomingCallDialog.show(context, testSession),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Incoming Audio Call'), findsOneWidget);
      expect(find.text('Ngozi Adebayo'), findsOneWidget);
      expect(find.text('TREASURER'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Tap decline icon button to dismiss dialog
      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Incoming Audio Call'), findsNothing);
    });
  });

  group('CallRingtoneService Tests', () {
    test('default ringtone asset is configured to sounds/ringtone.mp3', () {
      expect(CallRingtoneService.defaultRingtoneAsset, 'sounds/ringtone.mp3');
    });

    test('startRinging and stop toggles isPlaying properly', () {
      final service = CallRingtoneService();
      expect(service.isPlaying, isFalse);

      service.startRinging();
      expect(service.isPlaying, isTrue);

      service.stop();
      expect(service.isPlaying, isFalse);
    });

    test('startOutgoingRing and stop toggles isPlaying properly', () {
      final service = CallRingtoneService();
      expect(service.isPlaying, isFalse);

      service.startOutgoingRing();
      expect(service.isPlaying, isTrue);

      service.stop();
      expect(service.isPlaying, isFalse);
    });

    test('dispose cleans up service gracefully', () {
      final service = CallRingtoneService();
      service.startRinging();
      expect(service.isPlaying, isTrue);

      service.dispose();
      expect(service.isPlaying, isFalse);
    });
  });

  group('ProximitySensorService Tests', () {
    const channel = MethodChannel('com.agegrade.cls/proximity');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'isSupported') {
          return true;
        }
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isSupported queries platform channel and returns true', () async {
      final service = ProximitySensorService();
      final supported = await service.isSupported();
      expect(supported, isTrue);
      expect(log.single.method, 'isSupported');
    });

    test('enable calls enable method on platform channel and sets isEnabled', () async {
      final service = ProximitySensorService();
      expect(service.isEnabled, isFalse);

      await service.enable();
      expect(service.isEnabled, isTrue);
      expect(log.single.method, 'enable');

      // Calling enable again should not re-invoke channel
      await service.enable();
      expect(log.length, 1);
    });

    test('disable calls disable method on platform channel and sets isEnabled to false', () async {
      final service = ProximitySensorService();
      await service.enable();
      expect(service.isEnabled, isTrue);

      await service.disable();
      expect(service.isEnabled, isFalse);
      expect(log.map((m) => m.method).toList(), ['enable', 'disable']);

      // Calling disable again should not re-invoke channel
      await service.disable();
      expect(log.length, 2);
    });
  });
}
