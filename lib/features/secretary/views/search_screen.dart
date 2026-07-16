import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/secretary/controllers/search_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/models/document_model.dart';
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
              padding: const EdgeInsets.all(16),
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
                    ),
                  );
                } else if (item is MeetingModel) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.event)),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(item.meetingDate)),
                    ),
                  );
                } else if (item is AnnouncementModel) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.campaign)),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(item.category.name.toUpperCase()),
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
      final members = await controller.searchMembers(query);
      final meetings = await controller.searchMeetings(query);
      final announcements = user != null ? await controller.searchAnnouncements(query, user.uid) : [];
      final documents = user != null ? await controller.searchDocuments(query, user.uid) : [];
      setState(() {
        _results = [...members, ...meetings, ...announcements, ...documents];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
