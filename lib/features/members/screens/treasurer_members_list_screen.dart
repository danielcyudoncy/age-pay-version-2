// features/members/screens/treasurer_members_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/dashboard/providers/treasurer_dashboard_provider.dart';
import 'package:cls/features/members/screens/treasurer_member_detail_screen.dart';

class TreasurerMembersListScreen extends ConsumerStatefulWidget {
  const TreasurerMembersListScreen({super.key});

  @override
  ConsumerState<TreasurerMembersListScreen> createState() =>
      _TreasurerMembersListScreenState();
}

class _TreasurerMembersListScreenState
    extends ConsumerState<TreasurerMembersListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Registered Members'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final filtered = _query.isEmpty
                    ? members
                    : members.where((m) {
                        final q = _query;
                        return m.fullName.toLowerCase().contains(q) ||
                            m.email.toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No members found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            member.fullName.isNotEmpty
                                ? member.fullName[0]
                                : '?',
                          ),
                        ),
                        title: Text(member.fullName),
                        subtitle: Text(
                          'Joined ${dateFormat.format(member.joinedDate)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TreasurerMemberDetailScreen(
                                    memberId: member.userId,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
