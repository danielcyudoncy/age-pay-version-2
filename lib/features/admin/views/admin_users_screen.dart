import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../auth/models/user_model.dart';
import '../controllers/admin_provider.dart';
import '../widgets/edit_user_role_dialog.dart';
import '../widgets/reassign_branch_dialog.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  final bool filterPending;

  const AdminUsersScreen({
    super.key,
    this.filterPending = false,
  });

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  UserRole? _selectedRoleFilter;
  String _statusFilter = 'All'; // 'All', 'Approved', 'Pending', 'Inactive'

  @override
  void initState() {
    super.initState();
    if (widget.filterPending) {
      _statusFilter = 'Pending';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(allUsersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Users & Access Governance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(allUsersStreamProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, phone, branch...',
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

          // Horizontal Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildStatusChip('All'),
                const SizedBox(width: 8),
                _buildStatusChip('Approved'),
                const SizedBox(width: 8),
                _buildStatusChip('Pending'),
                const SizedBox(width: 8),
                _buildStatusChip('Inactive'),
                const SizedBox(width: 12),
                // Role Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole?>(
                      value: _selectedRoleFilter,
                      hint: const Text('Filter by Role', style: TextStyle(fontSize: 12)),
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Roles', style: TextStyle(fontSize: 12)),
                        ),
                        ...UserRole.values.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r.displayName, style: const TextStyle(fontSize: 12)),
                          );
                        }),
                      ],
                      onChanged: (role) {
                        setState(() => _selectedRoleFilter = role);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // User List
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final filtered = users.where((u) {
                  // Search query
                  if (_query.isNotEmpty) {
                    final q = _query;
                    final matches = u.displayName.toLowerCase().contains(q) ||
                        u.email.toLowerCase().contains(q) ||
                        u.phoneNumber.toLowerCase().contains(q) ||
                        (u.branchName?.toLowerCase().contains(q) ?? false);
                    if (!matches) return false;
                  }

                  // Status filter
                  if (_statusFilter == 'Approved') {
                    if (u.status != AccountStatus.approved || !u.isActive) return false;
                  } else if (_statusFilter == 'Pending') {
                    if (u.status != AccountStatus.pendingApproval) return false;
                  } else if (_statusFilter == 'Inactive') {
                    if (u.isActive && u.status != AccountStatus.suspended) return false;
                  }

                  // Role filter
                  if (_selectedRoleFilter != null) {
                    if (u.role != _selectedRoleFilter && u.nationalRole != _selectedRoleFilter) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No users match your criteria.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return _buildUserCard(context, user);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading users: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _statusFilter == label;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
      selectedColor: theme.colorScheme.primary,
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = label);
        }
      },
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final userRepo = ref.read(adminUserRepositoryProvider);
    final isPending = user.status == AccountStatus.pendingApproval;
    final isSuspended = !user.isActive || user.status == AccountStatus.suspended;

    Color statusColor = Colors.green;
    String statusText = 'Approved';
    if (isPending) {
      statusColor = Colors.orange;
      statusText = 'Pending Approval';
    } else if (isSuspended) {
      statusColor = Colors.red;
      statusText = 'Inactive / Suspended';
    }

    final initials = user.displayName.isNotEmpty
        ? user.displayName.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : (user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Name, Badges, Popup Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isNotEmpty ? user.displayName : user.email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user.role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getRoleColor(user.role).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              user.role.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(user.role),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // National Role Badge if present
                          if (user.nationalRole != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'National ${user.nationalRole!.displayName}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // More Actions Popup Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                  tooltip: 'User options',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit_role':
                        showDialog(
                          context: context,
                          builder: (_) => EditUserRoleDialog(
                            user: user,
                            onSave: (role, natRole, clearNat) async {
                              await userRepo.updateUserRole(
                                user.uid,
                                role: role,
                                nationalRole: natRole,
                                clearNationalRole: clearNat,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('User role updated successfully.')),
                                );
                              }
                            },
                          ),
                        );
                        break;
                      case 'reassign_branch':
                        showDialog(
                          context: context,
                          builder: (_) => ReassignBranchDialog(
                            user: user,
                            onSave: (orgId, bId, bName) async {
                              await userRepo.reassignUserBranch(
                                user.uid,
                                organizationId: orgId,
                                branchId: bId,
                                branchName: bName,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('User reassigned to $bName.')),
                                );
                              }
                            },
                          ),
                        );
                        break;
                      case 'approve':
                        await userRepo.updateUserStatus(
                          user.uid,
                          isActive: true,
                          status: AccountStatus.approved,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User account approved.')),
                          );
                        }
                        break;
                      case 'toggle_status':
                        final newActive = !user.isActive;
                        await userRepo.updateUserStatus(
                          user.uid,
                          isActive: newActive,
                          status: newActive ? AccountStatus.approved : AccountStatus.suspended,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newActive ? 'Account activated.' : 'Account suspended / deactivated.',
                              ),
                            ),
                          );
                        }
                        break;
                      case 'toggle_super_admin':
                        final makeSuper = user.role != UserRole.superAdmin;
                        await userRepo.toggleSuperAdmin(user.uid, makeSuper);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                makeSuper
                                    ? 'Super Admin permissions granted.'
                                    : 'Super Admin permissions revoked.',
                              ),
                            ),
                          );
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_role',
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Edit Role & Permissions')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reassign_branch',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Reassign Branch / Org')),
                        ],
                      ),
                    ),
                    if (isPending)
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Approve Account', style: TextStyle(color: Colors.green)),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive ? Icons.block_outlined : Icons.check_outlined,
                            size: 20,
                            color: user.isActive ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              user.isActive ? 'Suspend / Deactivate' : 'Activate Account',
                              style: TextStyle(
                                color: user.isActive ? Colors.orange : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'toggle_super_admin',
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 20,
                            color: user.role == UserRole.superAdmin ? Colors.red : Colors.purple,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              user.role == UserRole.superAdmin
                                  ? 'Revoke Super Admin'
                                  : 'Make Super Admin',
                              style: TextStyle(
                                color: user.role == UserRole.superAdmin ? Colors.red : Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            // Row 2: Contact info & branch details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (user.email.isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  user.email,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (user.phoneNumber.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.phoneNumber,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                user.branchName != null && user.branchName!.isNotEmpty
                                    ? user.branchName!
                                    : 'No branch assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMM yyyy').format(user.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.president:
        return Colors.amber.shade800;
      case UserRole.vicePresident:
        return Colors.amber.shade700;
      case UserRole.secretary:
      case UserRole.viceSecretary:
        return Colors.teal;
      case UserRole.treasurer:
      case UserRole.viceTreasurer:
      case UserRole.financialSecretary:
        return Colors.green.shade700;
      case UserRole.publicRelationsOfficer:
        return Colors.blue;
      case UserRole.provost:
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }
}
