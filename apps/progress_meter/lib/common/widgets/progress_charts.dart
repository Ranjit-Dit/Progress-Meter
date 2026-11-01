import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A normalized (0–100) trend with an optional benchmark series.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.values,
    this.comparison,
    this.labels,
    this.color = const Color(0xFF367C62),
    this.height = 215,
  });

  final List<double> values;
  final List<double>? comparison;
  final List<String>? labels;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final String description = values.isEmpty
        ? 'No progress records yet'
        : 'Progress trend, ${values.length} records. Latest score '
              '${values.last.round()} out of 100.';
    return Semantics(
      label: description,
      image: true,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _LinePainter(
            values: values,
            comparison: comparison,
            labels: labels,
            color: color,
            textColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: values.isEmpty
              ? const Center(child: Text('Your next chapter starts here'))
              : null,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.comparison,
    required this.labels,
    required this.color,
    required this.textColor,
  });

  final List<double> values;
  final List<double>? comparison;
  final List<String>? labels;
  final Color color;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    // A chart can briefly receive zero or tiny constraints while a responsive
    // layout is changing. There is no usable plot area in that case.
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 48 ||
        size.height <= 48) {
      return;
    }
    const left = 31.0;
    const top = 13.0;
    final right = size.width - 13;
    final bottom = size.height - 30;
    final width = math.max(1.0, right - left);
    final height = math.max(1.0, bottom - top);
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EDE9)
      ..strokeWidth = 1;
    for (final value in <int>[0, 25, 50, 75, 100]) {
      final y = bottom - value / 100 * height;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      _text(canvas, '$value', Offset(0, y - 6), textColor, 10);
    }
    if (values.isEmpty) return;

    List<Offset> pointsFor(List<double> data) => [
      for (var index = 0; index < data.length; index++)
        Offset(
          left + (data.length == 1 ? .5 : index / (data.length - 1)) * width,
          bottom - data[index].clamp(0, 100) / 100 * height,
        ),
    ];

    final points = pointsFor(values);
    final trend = _curve(points);
    final area = Path.from(trend)
      ..lineTo(points.last.dx, bottom)
      ..lineTo(points.first.dx, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .16), color.withValues(alpha: .005)],
        ).createShader(Rect.fromLTRB(left, top, right, bottom)),
    );
    final benchmark = comparison;
    if (benchmark != null && benchmark.isNotEmpty) {
      final path = _curve(pointsFor(benchmark));
      final paint = Paint()
        ..color = const Color(0xFFA5B5A7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final metric in path.computeMetrics()) {
        for (double distance = 0; distance < metric.length; distance += 11) {
          canvas.drawPath(
            metric.extractPath(distance, math.min(distance + 5, metric.length)),
            paint,
          );
        }
      }
    }
    canvas.drawPath(
      trend,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        2.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(points.last, 5.5, Paint()..color = color);
    canvas.drawCircle(points.last, 2.2, Paint()..color = Colors.white);

    final captions = labels;
    if (captions != null && captions.isNotEmpty) {
      // Limit visible ticks so labels stay readable on mobile layouts.
      final tickCount = math.min(captions.length, size.width < 400 ? 4 : 6);
      for (var tick = 0; tick < tickCount; tick++) {
        final fraction = tickCount == 1 ? .5 : tick / (tickCount - 1);
        final index = (fraction * (captions.length - 1)).round();
        final x = left + fraction * width;
        final painter = TextPainter(
          text: TextSpan(
            text: captions[index],
            style: TextStyle(color: textColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 80);
        painter.paint(
          canvas,
          Offset(
            (x - painter.width / 2).clamp(
              0,
              math.max(0.0, size.width - painter.width),
            ),
            bottom + 13,
          ),
        );
      }
    }
  }

  Path _curve(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final before = points[index - 1];
      final current = points[index];
      final middle = (before.dx + current.dx) / 2;
      path.cubicTo(
        middle,
        before.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.comparison != comparison ||
      oldDelegate.labels != labels ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor;
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = 136,
    this.color = const Color(0xFF367C62),
  });

  final double score;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progress score ${score.round()} out of 100',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(score: score, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.round()}',
                style: TextStyle(
                  fontSize: size * .28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -1.5,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: size * .09,
                  color: color.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.score, required this.color});
  final double score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .065;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2 + 3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = color.withValues(alpha: .12),
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * score.clamp(0, 100) / 100,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.label,
    required this.value,
    this.target,
    this.color = const Color(0xFF367C62),
  });

  final String label;
  final double value;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label: ${value.round()} out of 100${target == null ? '' : ', target ${target!.round()}'}',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (target != null)
                Text(
                  ' / ${target!.round()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: 7,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value.clamp(0, 100) / 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const SizedBox(height: 7),
                    ),
                  ),
                  if (target != null)
                    Positioned(
                      left:
                          (constraints.maxWidth - 2) *
                          target!.clamp(0, 100) /
                          100,
                      top: -2,
                      child: Container(
                        width: 2,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF304B40),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
