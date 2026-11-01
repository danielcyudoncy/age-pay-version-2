import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../members/models/member_model.dart';
import '../../members/repositories/member_repository.dart';
import '../widgets/member_call_button.dart';

final branchMembersStreamProvider =
    StreamProvider.autoDispose<List<MemberModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final memberRepo = MemberRepository();
  return memberRepo.getMembers().map((members) {
    // If user has a branch, filter members by branchId
    if (user.branchId != null && user.branchId!.isNotEmpty) {
      return members.where((m) => m.branchId == user.branchId).toList();
    }
    // If superAdmin or national executive without branch, show all organization members
    return members;
  });
});

class BranchDirectoryScreen extends ConsumerStatefulWidget {
  const BranchDirectoryScreen({super.key});

  @override
  ConsumerState<BranchDirectoryScreen> createState() =>
      _BranchDirectoryScreenState();
}

class _BranchDirectoryScreenState extends ConsumerState<BranchDirectoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final membersAsync = ref.watch(branchMembersStreamProvider);
    final theme = Theme.of(context);

    final branchTitle = (user?.branchName != null && user!.branchName!.isNotEmpty)
        ? '${user.branchName} Directory'
        : 'Branch Directory';

    return Scaffold(
      appBar: AppBar(
        title: Text(branchTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(branchMembersStreamProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Informative banner about In-App Audio Calling
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.brandGreen.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: AppTheme.brandGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'In-app audio calling connects you directly to fellow members over mobile data / Wi-Fi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (val) {
                setState(() => _query = val.trim().toLowerCase());
              },
            ),
          ),

          // Member List
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final filtered = members.where((m) {
                  if (_query.isEmpty) return true;
                  final name = m.fullName.toLowerCase();
                  final phone = m.phoneNumber.toLowerCase();
                  return name.contains(_query) || phone.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'No registered members found in this branch.'
                                : 'No members match "$_query".',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    final isCurrentUser = user != null &&
                        (user.uid == member.userId || user.uid == member.id);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                member.fullName.isNotEmpty
                                    ? member.fullName[0].toUpperCase()
                                    : 'M',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          member.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'YOU',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    member.phoneNumber.isNotEmpty
                                        ? member.phoneNumber
                                        : 'No phone number',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // In-App Audio Call Button
                            if (!isCurrentUser)
                              MemberCallButton(member: member),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Failed to load branch directory: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
