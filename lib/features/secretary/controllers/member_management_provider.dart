import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';

import '../../obligations/repositories/obligation_repository.dart';

final memberManagementRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository();
});

final memberManagementControllerProvider = Provider<MemberManagementController>((ref) {
  return MemberManagementController(ref.watch(memberManagementRepositoryProvider));
});

class MemberManagementController {
  final MemberRepository _repository;
  final ObligationRepository _obligationRepository = ObligationRepository();
  MemberManagementController(this._repository);

  Future<String> addMember(MemberModel member) async {
    final memberId = await _repository.createMember(member);
    await _obligationRepository.reconcileMemberObligations(
      memberId,
      userId: member.userId.isNotEmpty ? member.userId : null,
    );
    return memberId;
  }

  Future<void> updateMember(MemberModel member) {
    return _repository.updateMember(member);
  }

  Future<void> suspendMember(String id) async {
    final member = await _repository.getMemberById(id);
    if (member != null) {
      await _repository.updateLifecycleStatus(
        memberId: id,
        status: MembershipLifecycleStatus.suspended,
        userId: member.userId,
      );
    }
  }

  Future<void> activateMember(String id) async {
    final member = await _repository.getMemberById(id);
    if (member != null) {
      await _repository.updateLifecycleStatus(
        memberId: id,
        status: MembershipLifecycleStatus.active,
        userId: member.userId,
      );
    }
  }

  Future<void> updateLifecycleStatus(
    String id,
    MembershipLifecycleStatus lifecycleStatus, {
    String? userId,
  }) {
    return _repository.updateLifecycleStatus(
      memberId: id,
      status: lifecycleStatus,
      userId: userId,
    );
  }

  Future<void> setNationalEnrollment({
    required String memberId,
    required bool isEnrolled,
    required String byUserId,
  }) {
    return _repository.setNationalEnrollment(
      memberId: memberId,
      isEnrolled: isEnrolled,
      byUserId: byUserId,
    );
  }

  Future<List<MemberModel>> searchMembers(String query) {
    return _repository.searchMembers(query);
  }
}
