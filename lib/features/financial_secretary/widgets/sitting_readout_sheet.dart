import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/meetings/controllers/meeting_provider.dart';
import '../controllers/sitting_collection_provider.dart';
import '../views/cash_handover_screen.dart';

class SittingReadoutSheet extends ConsumerWidget {
  const SittingReadoutSheet({super.key});

  /// Opens the modal bottom sheet from anywhere in the application.
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SittingReadoutSheet(),
    );
  }

  /// Dialog to select sitting date or pick from scheduled meetings.
  static Future<void> pickSittingDateOrMeeting(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final meetings = ref.read(meetingsStreamProvider).valueOrNull ?? [];
    final currentDate = ref.read(selectedSittingDateProvider);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Sitting Date or Meeting'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.today, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    "Today's Sitting",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now())),
                  onTap: () {
                    ref.read(sittingScopeModeProvider.notifier).state = SittingScopeMode.today;
                    ref.read(selectedSittingDateProvider.notifier).state = DateTime.now();
                    ref.read(selectedSittingMeetingTitleProvider.notifier).state = null;
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(),
                if (meetings.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Choose Scheduled Meeting Sitting:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  ...meetings.take(6).map((m) {
                    final isSelected = m.meetingDate.year == currentDate.year &&
                        m.meetingDate.month == currentDate.month &&
                        m.meetingDate.day == currentDate.day;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.event_seat_outlined,
                        color: isSelected ? Colors.teal : null,
                      ),
                      title: Text(
                        m.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.teal : null,
                        ),
                      ),
                      subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(m.meetingDate)),
                      onTap: () {
                        ref.read(sittingScopeModeProvider.notifier).state = SittingScopeMode.customDate;
                        ref.read(selectedSittingDateProvider.notifier).state = m.meetingDate;
                        ref.read(selectedSittingMeetingTitleProvider.notifier).state = m.title;
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  const Divider(),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Pick Calendar Date...'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: currentDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 730)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      ref.read(sittingScopeModeProvider.notifier).state = SittingScopeMode.customDate;
                      ref.read(selectedSittingDateProvider.notifier).state = picked;
                      ref.read(selectedSittingMeetingTitleProvider.notifier).state = null;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final summaryAsync = ref.watch(sittingCollectionSummaryProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: summaryAsync.when(
            data: (model) {
              final formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(model.date);
              final subtitle = model.meetingTitle != null && model.meetingTitle!.isNotEmpty
                  ? '${model.meetingTitle} • $formattedDate'
                  : formattedDate;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.campaign, color: Colors.teal, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sitting Financial Disclosure',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined, size: 20),
                        tooltip: 'Change Sitting Date',
                        onPressed: () => pickSittingDateOrMeeting(context, ref),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grand Total Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0D3B36), const Color(0xFF134E48)]
                            : [const Color(0xFFE6F4F1), const Color(0xFFD0EBE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL REALIZED FOR SITTING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.teal.shade200 : Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currency.format(model.totalCollected),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0A4038),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${model.totalTransactions} Transaction${model.totalTransactions == 1 ? '' : 's'} • ${model.uniqueContributorsCount} Contributing Member${model.uniqueContributorsCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cash vs Bank Channel Breakdown
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.payments, size: 16, color: Colors.teal),
                                  SizedBox(width: 6),
                                  Text(
                                    'Cash in Hand',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currency.format(model.cashCollected),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.account_balance, size: 16, color: Colors.blue),
                                  SizedBox(width: 6),
                                  Text(
                                    'Bank / Online',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currency.format(model.bankCollected + model.onlineCollected),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dues & Levies Breakdown Section
                  Text(
                    'Collection Breakdown by Dues / Levy',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (model.levyBreakdowns.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No approved collections documented for this date.',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...model.levyBreakdowns.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.label_important_outline, size: 16, color: Colors.teal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(item.amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '${item.count} payment${item.count == 1 ? '' : 's'}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 18),

                  // Roll of Contributors Section
                  Text(
                    'Roll of Contributors (${model.contributors.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (model.contributors.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No member payments received on this sitting date yet.',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: model.contributors.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final c = model.contributors[index];
                          final isCash = c.method == PaymentMethod.cash;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: CircleAvatar(
                              radius: 13,
                              backgroundColor: isCash
                                  ? Colors.teal.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCash ? Colors.teal : Colors.blue,
                                ),
                              ),
                            ),
                            title: Text(
                              c.memberName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${isCash ? 'Cash' : 'Bank Transfer'} • ${DateFormat('hh:mm a').format(c.time)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              currency.format(c.amount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCash ? Colors.teal : Colors.blue.shade700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy_all, size: 20),
                      label: const Text(
                        'Copy Summary for Secretary Minutes',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: model.generateMinutesDisclosureText()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text(
                              'Sitting disclosure copied! The General Secretary can paste this into the official minutes.',
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ),

                  if (model.cashCollected > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.sync_alt, size: 18),
                        label: Text(
                          'Hand Over ${currency.format(model.cashCollected)} Cash to Treasurer',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          final sittingNotes = model.meetingTitle != null && model.meetingTitle!.isNotEmpty
                              ? '${model.meetingTitle} (${DateFormat('MMM dd').format(model.date)}) sitting collections'
                              : 'Sitting collections for ${DateFormat('MMM dd, yyyy').format(model.date)}';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CashHandoverScreen(
                                initialAmount: model.cashCollected,
                                initialNotes: sittingNotes,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error computing sitting collections: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
