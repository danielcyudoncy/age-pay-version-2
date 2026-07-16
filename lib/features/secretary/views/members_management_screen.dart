import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/secretary/controllers/member_management_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/views/edit_member_screen.dart';
import 'package:cls/features/members/views/member_profile_screen.dart';

class MembersManagementScreen extends ConsumerStatefulWidget {
  const MembersManagementScreen({super.key});

  @override
  ConsumerState<MembersManagementScreen> createState() => _MembersManagementScreenState();
}

class _MembersManagementScreenState extends ConsumerState<MembersManagementScreen> {
  final _searchController = TextEditingController();
  List<MemberModel> _allMembers = [];
  List<MemberModel> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(memberManagementRepositoryProvider);
      final members = await repo.getMembers().first;
      setState(() {
        _allMembers = members;
        _filtered = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allMembers
          : _allMembers.where((m) => m.fullName.toLowerCase().contains(query) || m.email.toLowerCase().contains(query) || m.phoneNumber.contains(query)).toList();
    });
  }

  Future<void> _toggleStatus(MemberModel member) async {
    final controller = ref.read(memberManagementControllerProvider);
    try {
      if (member.isActive) {
        await controller.suspendMember(member.id);
      } else {
        await controller.activateMember(member.id);
      }
      _loadMembers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(member.isActive ? 'Member suspended' : 'Member activated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberProfileScreen()));
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMembers,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear()) : null,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _filtered.isEmpty
                  ? Center(child: Column(children: [Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400), const SizedBox(height: 12), const Text('No members found')]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final member = _filtered[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: member.isActive ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                              child: Icon(member.isActive ? Icons.check : Icons.block, color: member.isActive ? Colors.green : Colors.red),
                            ),
                            title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${member.email} \u2022 Joined ${dateFormat.format(member.joinedDate)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(member.isActive ? Icons.block : Icons.check, color: member.isActive ? Colors.red : Colors.green), onPressed: () => _toggleStatus(member)),
                                IconButton(icon: const Icon(Icons.edit), onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => EditMemberScreen(member: member)));
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
