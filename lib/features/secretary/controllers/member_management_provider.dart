import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';

final memberManagementRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository();
});

final memberManagementControllerProvider = Provider<MemberManagementController>((ref) {
  return MemberManagementController(ref.watch(memberManagementRepositoryProvider));
});

class MemberManagementController {
  final MemberRepository _repository;
  MemberManagementController(this._repository);

  Future<String> addMember(MemberModel member) {
    return _repository.createMember(member);
  }

  Future<void> updateMember(MemberModel member) {
    return _repository.updateMember(member);
  }

  Future<void> suspendMember(String id) async {
    final member = await _repository.getMemberById(id);
    if (member != null) {
      await _repository.updateMember(member.copyWith(isActive: false));
    }
  }

  Future<void> activateMember(String id) async {
    final member = await _repository.getMemberById(id);
    if (member != null) {
      await _repository.updateMember(member.copyWith(isActive: true));
    }
  }

  Future<List<MemberModel>> searchMembers(String query) {
    return _repository.searchMembers(query);
  }
}
