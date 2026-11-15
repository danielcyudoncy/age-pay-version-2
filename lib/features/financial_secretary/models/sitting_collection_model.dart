import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/payments/models/payment_model.dart';

/// Represents collection for a single levy/dues category in a sitting.
class SittingLevyBreakdown {
  final String title;
  final double amount;
  final int count;

  const SittingLevyBreakdown({
    required this.title,
    required this.amount,
    required this.count,
  });
}

/// Represents an individual member contribution during a sitting.
class SittingContributor {
  final String memberId;
  final String memberName;
  final double amount;
  final PaymentMethod method;
  final DateTime time;
  final String? notes;

  const SittingContributor({
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.method,
    required this.time,
    this.notes,
  });
}

/// Aggregated financial data for a specific day or meeting sitting.
class SittingCollectionModel {
  final DateTime date;
  final String? meetingTitle;
  final double totalCollected;
  final double cashCollected;
  final double bankCollected;
  final double onlineCollected;
  final int totalTransactions;
  final int uniqueContributorsCount;
  final List<SittingLevyBreakdown> levyBreakdowns;
  final List<SittingContributor> contributors;
  final List<PaymentModel> rawPayments;

  const SittingCollectionModel({
    required this.date,
    this.meetingTitle,
    required this.totalCollected,
    required this.cashCollected,
    required this.bankCollected,
    required this.onlineCollected,
    required this.totalTransactions,
    required this.uniqueContributorsCount,
    required this.levyBreakdowns,
    required this.contributors,
    required this.rawPayments,
  });

  /// Factory for an empty sitting day.
  factory SittingCollectionModel.empty(DateTime date, {String? meetingTitle}) {
    return SittingCollectionModel(
      date: date,
      meetingTitle: meetingTitle,
      totalCollected: 0.0,
      cashCollected: 0.0,
      bankCollected: 0.0,
      onlineCollected: 0.0,
      totalTransactions: 0,
      uniqueContributorsCount: 0,
      levyBreakdowns: const [],
      contributors: const [],
      rawPayments: const [],
    );
  }

  /// Formats the sitting disclosure into an official text statement
  /// ready to be copied into secretarial minutes or read aloud.
  String generateMinutesDisclosureText({String currencySymbol = '₦'}) {
    final currency = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);
    final dateStr = DateFormat('EEEE, MMMM dd, yyyy').format(date);
    final buffer = StringBuffer();

    buffer.writeln('📋 FINANCIAL SECRETARY SITTING DISCLOSURE');
    buffer.writeln('Date: $dateStr');
    if (meetingTitle != null && meetingTitle!.isNotEmpty) {
      buffer.writeln('Sitting: $meetingTitle');
    }
    buffer.writeln('──────────────────────────────────────────────────');
    buffer.writeln('• GRAND TOTAL REALIZED: ${currency.format(totalCollected)} ($totalTransactions transaction${totalTransactions == 1 ? '' : 's'})');
    buffer.writeln('  - Physical Cash in Hand: ${currency.format(cashCollected)}');
    buffer.writeln('  - Direct Bank Transfers: ${currency.format(bankCollected)}');
    if (onlineCollected > 0) {
      buffer.writeln('  - Online Gateway Receipts: ${currency.format(onlineCollected)}');
    }
    buffer.writeln('• Contributing Members: $uniqueContributorsCount');
    buffer.writeln();

    if (levyBreakdowns.isNotEmpty) {
      buffer.writeln('Collection Breakdown by Dues / Levy:');
      for (final item in levyBreakdowns) {
        buffer.writeln('  - ${item.title}: ${currency.format(item.amount)} (${item.count} payment${item.count == 1 ? '' : 's'})');
      }
      buffer.writeln();
    }

    if (contributors.isNotEmpty) {
      buffer.writeln('Roll of Contributing Members:');
      for (int i = 0; i < contributors.length; i++) {
        final c = contributors[i];
        final methodLabel = c.method == PaymentMethod.cash
            ? 'Cash'
            : (c.method == PaymentMethod.bankTransfer ? 'Transfer' : 'Online');
        buffer.writeln('  ${i + 1}. ${c.memberName} — ${currency.format(c.amount)} ($methodLabel)');
      }
      buffer.writeln();
    }

    buffer.writeln('Reconciliation & Handover:');
    if (cashCollected > 0) {
      buffer.writeln('Physical cash sum of ${currency.format(cashCollected)} reconciled for formal handover to the Treasurer.');
    } else {
      buffer.writeln('All payments received directly through digital/bank channels.');
    }

    return buffer.toString();
  }
}
