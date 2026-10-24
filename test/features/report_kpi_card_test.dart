// test/features/report_kpi_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/reports/widgets/report_kpi_card.dart';

void main() {
  testWidgets('ReportKpiCard displays multi-line title at consistent font size without aggressive downscaling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    child: ReportKpiCard(
                      title: 'Total Obligations',
                      value: '₦150,000.00',
                      icon: Icons.assignment_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ReportKpiCard(
                      title: 'Total Paid',
                      value: '₦100,000.00',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ReportKpiCard(
                      title: 'Outstanding Balance',
                      value: '₦50,000.00',
                      icon: Icons.pending_actions_outlined,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify all titles are present
    expect(find.text('Total Obligations'), findsOneWidget);
    expect(find.text('Total Paid'), findsOneWidget);
    expect(find.text('Outstanding Balance'), findsOneWidget);

    // Verify all values are present
    expect(find.text('₦150,000.00'), findsOneWidget);
    expect(find.text('₦100,000.00'), findsOneWidget);
    expect(find.text('₦50,000.00'), findsOneWidget);

    // Verify the title Text widgets have the same font size (11.0) and allow 2 lines
    final obligationsText = tester.widget<Text>(find.text('Total Obligations'));
    final totalPaidText = tester.widget<Text>(find.text('Total Paid'));
    final outstandingText = tester.widget<Text>(find.text('Outstanding Balance'));

    expect(obligationsText.maxLines, 2);
    expect(totalPaidText.maxLines, 2);
    expect(outstandingText.maxLines, 2);

    expect(obligationsText.style?.fontSize, 11.0);
    expect(totalPaidText.style?.fontSize, 11.0);
    expect(outstandingText.style?.fontSize, 11.0);

    // Verify cards have equal height in the IntrinsicHeight row
    final cardSizes = tester.renderObjectList<RenderBox>(find.byType(Card)).map((r) => r.size.height).toList();
    expect(cardSizes.length, 3);
    expect(cardSizes[0], equals(cardSizes[1]));
    expect(cardSizes[1], equals(cardSizes[2]));
  });
}
