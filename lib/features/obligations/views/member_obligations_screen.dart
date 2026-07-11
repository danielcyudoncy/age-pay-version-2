import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/obligation_widgets.dart';

class MemberObligationsScreen extends ConsumerWidget {
  final String memberId;

  const MemberObligationsScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligationsAsync = ref.watch(memberObligationsProvider(memberId));
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('My Obligations'), centerTitle: true),
      body: obligationsAsync.when(
        data: (obligations) {
          if (obligations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No obligations found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You are all caught up!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final totalOutstanding = obligations.fold<double>(
            0,
            (sum, o) => sum + o.outstandingBalance,
          );

          return Column(
            children: [
              _buildSummaryCard(
                context,
                obligations,
                totalOutstanding,
                currency,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: obligations.length,
                  itemBuilder: (context, index) {
                    final obligation = obligations[index];
                    return ObligationCard(
                      obligation: obligation,
                      currency: currency,
                      dateFormat: dateFormat,
                    );
                  },
                ),
              ),
            ],
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
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    List<ObligationModel> obligations,
    double totalOutstanding,
    NumberFormat currency,
  ) {
    final paidCount = obligations
        .where((o) => o.status == ObligationStatus.paid)
        .length;
    final partialCount = obligations
        .where((o) => o.status == ObligationStatus.partial)
        .length;
    final unpaidCount = obligations
        .where((o) => o.status == ObligationStatus.unpaid)
        .length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SummaryItem(
                    label: 'Total Outstanding',
                    value: currency.format(totalOutstanding),
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: SummaryItem(
                    label: 'Paid',
                    value: '$paidCount',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: SummaryItem(
                    label: 'Partial',
                    value: '$partialCount',
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: SummaryItem(
                    label: 'Unpaid',
                    value: '$unpaidCount',
                    color: Colors.red.shade300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



