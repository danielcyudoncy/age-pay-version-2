import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/controllers/admin_provider.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../levies/controllers/levy_provider.dart';
import '../controllers/national_provider.dart';
import '../models/branch_compliance_report.dart';
import '../models/national_contribution_record.dart';

class NationalHubScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const NationalHubScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<NationalHubScreen> createState() => _NationalHubScreenState();
}

class _NationalHubScreenState extends ConsumerState<NationalHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    final orgId = user?.organizationId ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'National Assembly & Treasury',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(nationalContributionsProvider(orgId));
              ref.invalidate(nationalMembersProvider(orgId));
              ref.invalidate(branchComplianceLeaderboardProvider(orgId));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandGreen,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: AppTheme.brandGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.receipt_long),
              text: 'Contributions',
            ),
            Tab(
              icon: Icon(Icons.groups_outlined),
              text: 'Assembly Roll',
            ),
            Tab(
              icon: Icon(Icons.leaderboard_outlined),
              text: 'Leaderboard',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ContributionsTab(orgId: orgId),
          _AssemblyDirectoryTab(
            orgId: orgId,
            searchController: _searchController,
          ),
          _LeaderboardTab(orgId: orgId),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: LIVE PUBLIC CONTRIBUTIONS STREAM
// ---------------------------------------------------------------------------
class _ContributionsTab extends ConsumerWidget {
  final String orgId;

  const _ContributionsTab({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contributionsAsync = ref.watch(nationalContributionsProvider(orgId));
    final leviesAsync = ref.watch(activeLeviesProvider);
    final selectedLevyId = ref.watch(selectedLeaderboardLevyIdProvider);
    final currencyFmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Column(
      children: [
        // Filter by National Levy
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surface,
          child: leviesAsync.when(
            data: (levies) {
              final nationalLevies =
                  levies.where((l) => l.scope == 'national').toList();
              return DropdownButtonFormField<String?>(
                initialValue: selectedLevyId,
                decoration: InputDecoration(
                  labelText: 'Filter by National Cause / Dues',
                  prefixIcon:
                      const Icon(Icons.filter_list, color: AppTheme.brandGreen),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All National Levies & Dues'),
                  ),
                  ...nationalLevies.map(
                    (l) => DropdownMenuItem<String?>(
                      value: l.id,
                      child: Text(
                        l.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  ref.read(selectedLeaderboardLevyIdProvider.notifier).state = val;
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: contributionsAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volunteer_activism_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No National Contributions Yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When members pay for national levies and dues, verified payments will appear here in real time for everyone to see.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final totalAmount =
                  records.fold<double>(0.0, (acc, r) => acc + r.amount);
              final uniqueBranches =
                  records.map((r) => r.branchName).toSet().length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // High-level Transparency Stats Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.brandGreen,
                          AppTheme.brandGreen.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandGreen.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Verified National Treasury Inflow',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFmt.format(totalAmount),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${records.length} Contributions Recorded',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              '$uniqueBranches Branches Participating',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Transparency Feed',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${records.length} total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...records.map((r) => _buildContributionCard(context, r, currencyFmt)),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading national contributions: $err'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContributionCard(
    BuildContext context,
    NationalContributionRecord record,
    NumberFormat currencyFmt,
  ) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(record.paidAt);
    final initials = record.memberName.trim().isNotEmpty
        ? record.memberName.trim().split(' ').map((e) => e[0]).take(2).join()
        : 'M';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.brandGreen.withValues(alpha: 0.12),
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.brandGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          record.memberName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        currencyFmt.format(record.amount),
                        style: const TextStyle(
                          color: AppTheme.brandGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_city,
                          size: 13, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          record.branchName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.levyTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        record.method == PaymentMethod.bankTransfer
                            ? 'Bank Transfer'
                            : 'Online / Card',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.brandGreen.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
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
}

// ---------------------------------------------------------------------------
// TAB 2: NATIONAL ASSEMBLY DIRECTORY (ALL MEMBERS ROLL)
// ---------------------------------------------------------------------------
class _AssemblyDirectoryTab extends ConsumerWidget {
  final String orgId;
  final TextEditingController searchController;

  const _AssemblyDirectoryTab({
    required this.orgId,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membersAsync = ref.watch(nationalMembersProvider(orgId));
    final branchesAsync = ref.watch(branchesStreamFamily(orgId));
    final searchQuery = ref.watch(nationalSearchQueryProvider);
    final selectedBranchId = ref.watch(nationalBranchFilterProvider);

    return Column(
      children: [
        // Search & Branch Filter Header
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search member by name or role...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            ref.read(nationalSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) {
                  ref.read(nationalSearchQueryProvider.notifier).state = val.trim();
                },
              ),
              const SizedBox(height: 8),

              // Branch Filter Chips
              branchesAsync.when(
                data: (branches) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All Branches'),
                          selected: selectedBranchId == null,
                          onSelected: (_) {
                            ref.read(nationalBranchFilterProvider.notifier).state =
                                null;
                          },
                        ),
                        const SizedBox(width: 6),
                        ...branches.map((b) {
                          final isSelected = selectedBranchId == b.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(b.name),
                              selected: isSelected,
                              onSelected: (_) {
                                ref
                                    .read(nationalBranchFilterProvider.notifier)
                                    .state = isSelected ? null : b.id;
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Member List
        Expanded(
          child: membersAsync.when(
            data: (members) {
              final query = searchQuery.toLowerCase();
              final filtered = members.where((m) {
                final matchesBranch =
                    selectedBranchId == null || m.branchId == selectedBranchId;
                final matchesQuery = query.isEmpty ||
                    m.displayName.toLowerCase().contains(query) ||
                    (m.branchName?.toLowerCase().contains(query) ?? false) ||
                    (m.nationalRole?.name.toLowerCase().contains(query) ?? false);
                return matchesBranch && matchesQuery;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No Members Found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No member matches "$searchQuery".'
                              : 'No members found in this branch filter.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${filtered.length} Member(s) in National Assembly',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  final member = filtered[index - 1];
                  return _buildMemberDirectoryTile(context, member);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error loading directory: $err'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberDirectoryTile(BuildContext context, UserModel member) {
    final theme = Theme.of(context);
    final initials = member.displayName.trim().isNotEmpty
        ? member.displayName.trim().split(' ').map((e) => e[0]).take(2).join()
        : 'M';
    final hasNationalRole = member.nationalRole != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasNationalRole
              ? AppTheme.brandGreen.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: hasNationalRole
              ? AppTheme.brandGreen
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            initials.toUpperCase(),
            style: TextStyle(
              color: hasNationalRole
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasNationalRole)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _formatRole(member.nationalRole!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.brandGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.location_city,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  member.branchName ?? 'Headquarters / Direct',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!hasNationalRole && member.role != UserRole.member)
                Text(
                  _formatRole(member.role),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(UserRole role) {
    return role.displayName;
  }
}

// ---------------------------------------------------------------------------
// TAB 3: BRANCH REMITTANCE LEADERBOARD
// ---------------------------------------------------------------------------
class _LeaderboardTab extends ConsumerWidget {
  final String orgId;

  const _LeaderboardTab({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leaderboardAsync = ref.watch(branchComplianceLeaderboardProvider(orgId));
    final currencyFmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return leaderboardAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No Branch Data Available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Branches will appear here with real-time remittance rankings once national obligations are generated.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final totalExpected =
            reports.fold<double>(0.0, (acc, r) => acc + r.totalExpected);
        final totalRemitted =
            reports.fold<double>(0.0, (acc, r) => acc + r.totalRemitted);
        final totalArrears =
            reports.fold<double>(0.0, (acc, r) => acc + r.outstandingBalance);
        final overallRate = totalExpected > 0
            ? ((totalRemitted / totalExpected) * 100).clamp(0.0, 100.0)
            : 100.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overall Stats Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Remittance Rate',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${overallRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _rateColor(overallRate),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (overallRate / 100).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _rateColor(overallRate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('Expected',
                            currencyFmt.format(totalExpected), Colors.grey[700]!),
                        _buildStatColumn('Remitted',
                            currencyFmt.format(totalRemitted), AppTheme.brandGreen),
                        _buildStatColumn('Arrears',
                            currencyFmt.format(totalArrears), Colors.red[700]!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Branch Rankings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${reports.length} branches',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...reports.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final report = entry.value;
              return _buildBranchCard(context, rank, report, currencyFmt);
            }),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading leaderboard: $err'),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBranchCard(
    BuildContext context,
    int rank,
    BranchComplianceReport report,
    NumberFormat currencyFmt,
  ) {
    final theme = Theme.of(context);
    final isTop = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isTop
              ? AppTheme.brandGreen.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.branchName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (report.isNational)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.brandGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'HQ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (report.city.isNotEmpty || report.state.isNotEmpty)
                        Text(
                          [report.city, report.state]
                              .where((s) => s.isNotEmpty)
                              .join(', '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildTierChip(report.complianceTier),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Compliance Rate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${report.complianceRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _rateColor(report.complianceRate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (report.complianceRate / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _rateColor(report.complianceRate),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubStat('Members', '${report.memberCount}'),
                  _buildSubStat('Expected', currencyFmt.format(report.totalExpected)),
                  _buildSubStat('Remitted', currencyFmt.format(report.totalRemitted)),
                  _buildSubStat('Arrears', currencyFmt.format(report.outstandingBalance)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bg;
    Color fg = Colors.white;

    switch (rank) {
      case 1:
        bg = const Color(0xFFFFD700);
        fg = Colors.black87;
        break;
      case 2:
        bg = const Color(0xFFC0C0C0);
        fg = Colors.black87;
        break;
      case 3:
        bg = const Color(0xFFCD7F32);
        break;
      default:
        bg = Colors.grey[200]!;
        fg = Colors.black87;
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTierChip(String tier) {
    Color bg;
    Color fg;

    switch (tier) {
      case 'Top Performing':
        bg = Colors.green[50]!;
        fg = Colors.green[800]!;
        break;
      case 'Compliant':
        bg = Colors.blue[50]!;
        fg = Colors.blue[800]!;
        break;
      case 'In Arrears':
        bg = Colors.orange[50]!;
        fg = Colors.orange[800]!;
        break;
      default:
        bg = Colors.red[50]!;
        fg = Colors.red[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tier,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 90.0) return Colors.green[700]!;
    if (rate >= 70.0) return Colors.blue[700]!;
    if (rate >= 40.0) return Colors.orange[700]!;
    return Colors.red[700]!;
  }
}
