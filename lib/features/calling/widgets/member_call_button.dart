import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../members/models/member_model.dart';
import '../controllers/call_controller.dart';

class MemberCallButton extends ConsumerWidget {
  final MemberModel member;
  final bool isCompact;

  const MemberCallButton({
    super.key,
    required this.member,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).valueOrNull;

    // Cannot call oneself
    final isSelf = currentUser != null &&
        (currentUser.uid == member.userId || currentUser.uid == member.id);

    if (isSelf) return const SizedBox.shrink();

    // In a multi-tenant association, members call within their organization & branch
    final canCall = currentUser != null &&
        (currentUser.branchId == null ||
         currentUser.branchId!.isEmpty ||
         member.branchId == null ||
         member.branchId!.isEmpty ||
         currentUser.branchId == member.branchId ||
         currentUser.nationalRole != null);

    if (!canCall) return const SizedBox.shrink();

    if (isCompact) {
      return IconButton(
        icon: const Icon(Icons.phone_in_talk, color: Colors.green),
        tooltip: 'Call ${member.fullName}',
        onPressed: () {
          ref.read(callControllerProvider).startCall(
                caller: currentUser,
                callee: member,
                context: context,
              );
        },
      );
    }

    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green.withValues(alpha: 0.12),
        foregroundColor: Colors.green.shade800,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      icon: const Icon(Icons.phone_in_talk, size: 16),
      label: const Text(
        'Call',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        ref.read(callControllerProvider).startCall(
              caller: currentUser,
              callee: member,
              context: context,
            );
      },
    );
  }
}

