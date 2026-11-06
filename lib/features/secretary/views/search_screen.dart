import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/secretary/controllers/search_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/models/document_model.dart';
import 'package:cls/features/calling/views/branch_directory_screen.dart';
import 'package:cls/features/calling/widgets/member_call_button.dart';
import 'package:cls/features/meetings/views/meeting_detail_screen.dart';
import '../widgets/announcement_detail_dialog.dart';
import 'package:intl/intl.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Colors.green),
            tooltip: 'Branch Calling Directory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BranchDirectoryScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search members, meetings, announcements...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _controller.clear(); setState(() => _results = []); }) : null,
              ),
              onChanged: (_) => _performSearch(),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? Center(child: Text('Enter a query to search', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                if (item is MemberModel) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(item.email),
                      trailing: MemberCallButton(member: item, isCompact: true),
                    ),
                  );
                } else if (item is MeetingModel) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.event)),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${DateFormat('MMM dd, yyyy').format(item.meetingDate)} • ${item.isExecutivesOnly ? 'Executives Only' : 'All Members'}'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MeetingDetailScreen(meeting: item, readOnly: true),
                          ),
                        );
                      },
                    ),
                  );
                } else if (item is AnnouncementModel) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.campaign)),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(item.category.name.toUpperCase()),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => showAnnouncementDetailDialog(context, item),
                    ),
                  );
                } else if (item is DocumentModel) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.folder)),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(item.category.name.replaceAll('_', ' ').toUpperCase()),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
    );
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(searchControllerProvider);
      final authState = ref.read(authProvider);
      final user = authState.valueOrNull;
      final orgId = user?.organizationId.isNotEmpty == true ? user!.organizationId : (user?.uid ?? '');
      final members = await controller.searchMembers(query);
      final allMeetings = await controller.searchMeetings(query);
      final userBranchId = user?.branchId;
      final meetings = allMeetings.where((m) {
        if (userBranchId != null && userBranchId.isNotEmpty) {
          return m.branchId == userBranchId ||
              (m.scope == 'national' && m.targetAudience == 'all');
        }
        return true;
      }).toList();
      final allAnnouncements = user != null
          ? await controller.searchAnnouncements(query, orgId)
          : <AnnouncementModel>[];
      final announcements =
          allAnnouncements.where((a) => a.isVisibleTo(user)).toList();
      final documents = user != null ? await controller.searchDocuments(query, orgId) : [];
      setState(() {
        _results = [...members, ...meetings, ...announcements, ...documents];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
