import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/common/widgets/progress_charts.dart';

Widget _host(Widget child, {double width = 320}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('empty progress explains the empty state accessibly', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ProgressLineChart(values: [])));

    expect(find.text('Your next chapter starts here'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('No progress records yet')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('one record and a longer benchmark render at a narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProgressLineChart(
          values: [72],
          comparison: [60, 70, 85],
          labels: ['Oct 29'],
        ),
        width: 240,
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('1 records. Latest score 72 out of 100')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart handles full range and redraws when the series changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProgressLineChart(
          values: [0, 25, 100],
          comparison: [20, 40, 80],
          labels: ['Aug', 'Sep', 'Oct'],
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(
        const ProgressLineChart(
          values: [0, 25, 100, 82],
          labels: ['Aug', 'Sep', 'Oct', 'Nov'],
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('Latest score 82 out of 100')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonempty chart fills available width in a loose column', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressLineChart(
              values: [35, 62, 78],
              labels: ['Aug', 'Sep', 'Oct'],
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(ProgressLineChart)).width, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero and tiny chart constraints do not cause paint exceptions', (
    tester,
  ) async {
    for (final width in <double>[0, 20, 49]) {
      await tester.pumpWidget(
        _host(
          const ProgressLineChart(
            values: [35, 62, 78],
            labels: ['A long date label', 'September', 'October'],
          ),
          width: width,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testWidgets('score and target remain available to screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreRing(score: 76.5),
            MetricBar(label: 'Practice', value: 63, target: 85),
          ],
        ),
      ),
    );

    expect(find.text('77'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Progress score 77 out of 100')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Practice: 63 out of 100, target 85')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
