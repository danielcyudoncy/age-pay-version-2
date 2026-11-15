import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/sitting_collection_provider.dart';
import 'sitting_readout_sheet.dart';

class SittingTallyCard extends ConsumerWidget {
  const SittingTallyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final summaryAsync = ref.watch(sittingCollectionSummaryProvider);
    final scopeMode = ref.watch(sittingScopeModeProvider);

    return summaryAsync.maybeWhen(
      data: (model) {
        final isToday = scopeMode == SittingScopeMode.today;
        final dateLabel = isToday
            ? "TODAY'S SITTING"
            : DateFormat('MMM dd, yyyy').format(model.date).toUpperCase();

        return Card(
          elevation: 1,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.teal.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          color: isDark ? const Color(0xFF0F2F2B) : const Color(0xFFF0FAF8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => SittingReadoutSheet.show(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Date Pill & Readout Trigger
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.today, size: 12, color: Colors.teal),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  model.meetingTitle != null && model.meetingTitle!.isNotEmpty
                                      ? '$dateLabel • ${model.meetingTitle!}'
                                      : '$dateLabel • ${DateFormat('EEE, MMM dd').format(model.date)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.campaign, size: 16, color: Colors.teal),
                          SizedBox(width: 4),
                          Text(
                            'Open Readout',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: Colors.teal),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Middle Row: Big Amount & Transaction Subtitle
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currency.format(model.totalCollected),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0D47A1).withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${model.totalTransactions} payment${model.totalTransactions == 1 ? '' : 's'})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bottom Micro Pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _MicroPill(
                        label: 'Cash in Hand',
                        value: currency.format(model.cashCollected),
                        color: Colors.teal,
                      ),
                      _MicroPill(
                        label: 'Bank/Transfer',
                        value: currency.format(model.bankCollected + model.onlineCollected),
                        color: Colors.blue,
                      ),
                      _MicroPill(
                        label: 'Contributors',
                        value: '${model.uniqueContributorsCount} members',
                        color: Colors.indigo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MicroPill extends StatelessWidget {
  final String label;
  final String value;
  final MaterialColor color;

  const _MicroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: color.shade800,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
