import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/secretary/controllers/member_management_provider.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/members/views/edit_member_screen.dart';
import 'package:cls/features/members/views/member_profile_screen.dart';
import 'package:cls/features/members/views/treasurer_member_detail_screen.dart';
import 'package:cls/features/calling/views/branch_directory_screen.dart';
import 'package:cls/features/calling/widgets/member_call_button.dart';

/// Management and directory screen for Branch Secretaries to view, search,
/// contact, and administer branch member rosters.
class MembersManagementScreen extends ConsumerStatefulWidget {
  const MembersManagementScreen({super.key});

  @override
  ConsumerState<MembersManagementScreen> createState() =>
      _MembersManagementScreenState();
}

class _MembersManagementScreenState
    extends ConsumerState<MembersManagementScreen> {
  final _searchController = TextEditingController();
  List<MemberModel> _allMembers = [];
  List<MemberModel> _filtered = [];
  bool _isLoading = true;
  String? _error;
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Suspended

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(memberManagementRepositoryProvider);
      final user = ref.read(authProvider).valueOrNull;
      final members = await repo.getAllMembers().first;

      // Scope members to secretary's branch if user is branch-scoped
      final isScopedBranch = user != null &&
          user.branchId != null &&
          user.branchId!.isNotEmpty &&
          user.role != UserRole.superAdmin &&
          user.nationalRole != UserRole.president;

      final scoped = isScopedBranch
          ? members.where((m) => m.branchId == user.branchId).toList()
          : members;

      if (!mounted) return;
      setState(() {
        _allMembers = scoped;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _allMembers.where((m) {
        // Status filter
        if (_selectedFilterIndex == 1 && !m.isActive) return false;
        if (_selectedFilterIndex == 2 && m.isActive) return false;

        // Search query
        if (query.isEmpty) return true;
        return m.fullName.toLowerCase().contains(query) ||
            m.email.toLowerCase().contains(query) ||
            m.phoneNumber.contains(query) ||
            (m.branchName?.toLowerCase().contains(query) ?? false);
      }).toList();
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
      if (mounted) _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              member.isActive ? 'Member suspended' : 'Member activated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _confirmToggleStatus(MemberModel member) async {
    final willSuspend = member.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(willSuspend ? 'Suspend Member?' : 'Activate Member?'),
        content: Text(
          willSuspend
              ? 'Are you sure you want to suspend ${member.fullName}? They will be marked as inactive in branch records.'
              : 'Are you sure you want to reactivate ${member.fullName} as an active member?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: willSuspend ? Colors.red : Colors.green,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(willSuspend ? 'Suspend' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _toggleStatus(member);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    final dateFormat = DateFormat('MMM dd, yyyy');

    final activeCount = _allMembers.where((m) => m.isActive).length;
    final suspendedCount = _allMembers.where((m) => !m.isActive).length;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Branch Members'),
            if (user?.branchName != null && user!.branchName!.isNotEmpty)
              Text(
                '${user.branchName} Roster',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
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
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MemberProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMembers,
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Segmented Status Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All (${_allMembers.length})',
                      isSelected: _selectedFilterIndex == 0,
                      onTap: () {
                        setState(() => _selectedFilterIndex = 0);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Active ($activeCount)',
                      isSelected: _selectedFilterIndex == 1,
                      accentColor: Colors.green,
                      onTap: () {
                        setState(() => _selectedFilterIndex = 1);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Suspended ($suspendedCount)',
                      isSelected: _selectedFilterIndex == 2,
                      accentColor: Colors.red,
                      onTap: () {
                        setState(() => _selectedFilterIndex = 2);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Members List or Empty / Loading States
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error loading members: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _loadMembers,
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filtered.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search_outlined,
                                      size: 54,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _allMembers.isEmpty
                                          ? 'No members registered yet'
                                          : 'No matching members found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _allMembers.isEmpty
                                          ? 'New branch members will appear here once registered.'
                                          : 'Try adjusting your search query or status filter.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                MediaQuery.paddingOf(context).bottom + 24,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final member = _filtered[index];
                                return _SecretaryMemberCard(
                                  key: ValueKey(member.id),
                                  member: member,
                                  dateFormat: dateFormat,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TreasurerMemberDetailScreen(
                                          memberId: member.userId.isNotEmpty
                                              ? member.userId
                                              : member.id,
                                          isReadOnly: true,
                                        ),
                                      ),
                                    );
                                  },
                                  onEdit: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditMemberScreen(
                                          member: member,
                                        ),
                                      ),
                                    );
                                  },
                                  onToggleStatus: () =>
                                      _confirmToggleStatus(member),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final activeColor = accentColor ?? theme.colorScheme.primary;

    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (accentColor != null ? Colors.white : theme.colorScheme.onPrimary)
              : theme.colorScheme.onSurface,
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: activeColor,
      checkmarkColor:
          accentColor != null ? Colors.white : theme.colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? activeColor
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }
}

/// Executive-styled directory card representing a branch member for the Secretary.
class _SecretaryMemberCard extends StatelessWidget {
  final MemberModel member;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _SecretaryMemberCard({
    super.key,
    required this.member,
    required this.dateFormat,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = member.isActive ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tier: Avatar with Status Indicator + Name & Branch + Status Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Online / Active status dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: (member.profilePhotoUrl != null &&
                                member.profilePhotoUrl!.isNotEmpty)
                            ? NetworkImage(member.profilePhotoUrl!)
                            : null,
                        child: (member.profilePhotoUrl == null ||
                                member.profilePhotoUrl!.isEmpty)
                            ? Text(
                                _getInitials(member.fullName),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Member Identity & Branch / Role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (member.branchName != null &&
                            member.branchName!.trim().isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  member.branchName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else if (member.role != null &&
                            member.role != UserRole.member)
                          Text(
                            member.role!.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          )
                        else
                          Text(
                            'Branch Member',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          member.isActive
                              ? Icons.check_circle_outline
                              : Icons.pause_circle_outline,
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.isActive ? 'Active' : 'Suspended',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Contact & Joined Details Tier
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (member.phoneNumber.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              member.phoneNumber,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    if (member.email.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              member.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Joined ${dateFormat.format(member.joinedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 0.6,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),

              // Action Footer Tier: Call + Edit + More Options Popup
              Row(
                children: [
                  // In-App Audio Call
                  MemberCallButton(member: member, isCompact: false),
                  const Spacer(),

                  // Edit Member Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit', style: TextStyle(fontSize: 13)),
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 4),

                  // More Options Menu (View Profile / Suspend / Activate)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'More actions',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'view') {
                        onTap();
                      } else if (value == 'toggle_status') {
                        onToggleStatus();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('View Profile'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(
                          children: [
                            Icon(
                              member.isActive
                                  ? Icons.block_outlined
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: member.isActive ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              member.isActive
                                  ? 'Suspend Member'
                                  : 'Activate Member',
                              style: TextStyle(
                                color:
                                    member.isActive ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
