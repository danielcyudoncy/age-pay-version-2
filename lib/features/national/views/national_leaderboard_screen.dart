import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../levies/controllers/levy_provider.dart';
import '../controllers/national_provider.dart';
import '../models/branch_compliance_report.dart';

class NationalLeaderboardScreen extends ConsumerWidget {
  const NationalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    final orgId = user?.organizationId ?? '';
    final leaderboardAsync = ref.watch(branchComplianceLeaderboardProvider(orgId));
    final leviesAsync = ref.watch(activeLeviesProvider);
    final selectedLevyId = ref.watch(selectedLeaderboardLevyIdProvider);

    final currencyFmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Branch Remittance Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(branchComplianceLeaderboardProvider(orgId));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surface,
              child: leviesAsync.when(
                data: (levies) {
                  final nationalLevies =
                      levies.where((l) => l.scope == 'national').toList();
                  return DropdownButtonFormField<String?>(
                    initialValue: selectedLevyId,
                    decoration: InputDecoration(
                      labelText: 'Select National Obligation / Levy',
                      prefixIcon: const Icon(Icons.filter_list, color: AppTheme.brandGreen),
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

            // Leaderboard Body
            Expanded(
              child: leaderboardAsync.when(
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

                  // Compute Summary
                  double totalExpectedAll = 0;
                  double totalRemittedAll = 0;
                  for (final r in reports) {
                    totalExpectedAll += r.totalExpected;
                    totalRemittedAll += r.totalRemitted;
                  }
                  final avgCompliance = totalExpectedAll > 0
                      ? ((totalRemittedAll / totalExpectedAll) * 100).clamp(0.0, 100.0)
                      : 100.0;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      // Overview Banner
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: AppTheme.brandGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        color: AppTheme.brandGreen.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Overall National Remittance',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFmt.format(totalRemittedAll),
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.brandGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${avgCompliance.toStringAsFixed(1)}% compliance across ${reports.length} branches',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Branch Rankings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...reports.asMap().entries.map((entry) {
                        final index = entry.key;
                        final report = entry.value;
                        return _buildBranchCard(
                          context,
                          theme,
                          report,
                          rank: index + 1,
                          currencyFmt: currencyFmt,
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load leaderboard: $err'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchCard(
    BuildContext context,
    ThemeData theme,
    BranchComplianceReport report, {
    required int rank,
    required NumberFormat currencyFmt,
  }) {
    Color rankColor;
    String rankBadge;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankBadge = '🥇 #1';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankBadge = '🥈 #2';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankBadge = '🥉 #3';
    } else {
      rankColor = theme.colorScheme.onSurfaceVariant;
      rankBadge = '#$rank';
    }

    Color tierColor;
    switch (report.complianceTier) {
      case 'Top Performing':
        tierColor = const Color(0xFF1B5E20);
        break;
      case 'Compliant':
        tierColor = Colors.blue.shade800;
        break;
      case 'In Arrears':
        tierColor = Colors.orange.shade800;
        break;
      default:
        tierColor = Colors.red.shade800;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rankColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    rankBadge,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: rankColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              report.branchName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (report.isNational) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.brandGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'HQ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${report.city}${report.state.isNotEmpty ? ', ${report.state}' : ''} • ${report.memberCount} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.complianceTier,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: report.complianceRate / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  report.complianceRate >= 70 ? AppTheme.brandGreen : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remitted',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      currencyFmt.format(report.totalRemitted),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.brandGreen,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Expected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      currencyFmt.format(report.totalExpected),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Outstanding',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      currencyFmt.format(report.outstandingBalance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: report.outstandingBalance > 0
                            ? Colors.red.shade700
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
