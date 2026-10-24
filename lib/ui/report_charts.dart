import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/report.dart';

// Charts for the investor update, ported from demo/investor-report/build.py.
// Painters take their colours from [ChartColors], so the screen can follow
// the theme and the PDF export can always render them light.

const chartBlue = Color(0xFF2A78D6);
const chartOrange = Color(0xFFEB6834);
const chartGood = Color(0xFF0CA30C);
const chartBad = Color(0xFFD03B3B);

class ChartColors {
  const ChartColors({required this.ink, required this.label, required this.grid, required this.surface});

  final Color ink;
  final Color label;
  final Color grid;
  final Color surface;

  static const light = ChartColors(
    ink: Color(0xFF0F1419),
    label: Color(0xFF64748B),
    grid: Color(0xFFE2E8F0),
    surface: Colors.white,
  );
}

/// "Oct 2026" for month 0, "Sep 2026" for -1.
String monthLabel(int m) => DateFormat('MMM yyyy').format(DateTime(2026, 10 + m));

String _eur(double v) => AppState.formatValue(v, 'EUR');

void _text(
  Canvas c,
  String s,
  Offset at,
  Color color, {
  double size = 11,
  FontWeight weight = FontWeight.w400,
  TextAlign align = TextAlign.left,
  double? maxWidth,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'GeistTtf', color: color, fontSize: size, fontWeight: weight),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: maxWidth ?? 400);
  final dx = switch (align) {
    TextAlign.right => at.dx - tp.width,
    TextAlign.center => at.dx - tp.width / 2,
    _ => at.dx,
  };
  tp.paint(c, Offset(dx, at.dy - tp.height / 2));
}

void _dashedLine(Canvas c, Offset a, Offset b, Paint p, {double dash = 4}) {
  final total = (b - a).distance;
  final dir = (b - a) / total;
  for (var d = 0.0; d < total; d += dash * 2) {
    c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
  }
}

Paint _stroke(Color color, [double width = 2]) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Monthly revenue against flat monthly expenses, from the September close
/// through the projection, with the break-even month marked.
class RevenueChartPainter extends CustomPainter {
  RevenueChartPainter(this.d, this.colors);

  final DefaultAlive d;
  final ChartColors colors;

  @override
  void paint(Canvas c, Size size) {
    const l = 64.0, r = 132.0, t = 18.0, b = 34.0;
    final pw = size.width - l - r, ph = size.height - t - b;
    final points = [...d.history, ...d.projection];
    final first = points.first.month, last = points.last.month;
    final top = (points.map((p) => math.max(p.revenue, p.expenses)).reduce(math.max) / 100000).ceil() * 100000.0;
    double x(int m) => l + (m - first) / (last - first) * pw;
    double y(double v) => t + ph - math.min(v, top) / top * ph;

    for (var v = 0.0; v <= top; v += 100000) {
      c.drawLine(Offset(l, y(v)), Offset(l + pw, y(v)), _stroke(colors.grid, 1));
      _text(c, _eur(v), Offset(l - 8, y(v)), colors.label, align: TextAlign.right);
    }
    for (final p in points) {
      if ((p.month - first) % 3 == 0) {
        _text(c, monthLabel(p.month), Offset(x(p.month), size.height - 14), colors.label, align: TextAlign.center);
      }
    }
    // Break-even marker.
    final bx = x(d.months);
    _dashedLine(c, Offset(bx, t), Offset(bx, t + ph), _stroke(colors.ink, 1.2));
    _text(
      c,
      'Break-even, ${monthLabel(d.months)}',
      Offset(bx - 6, t + 6),
      colors.ink,
      align: TextAlign.right,
      weight: FontWeight.w600,
      size: 11.5,
    );

    Path line(double Function(ProjectionPoint) v) {
      final path = Path()..moveTo(x(points.first.month), y(v(points.first)));
      for (final p in points.skip(1)) {
        path.lineTo(x(p.month), y(v(p)));
      }
      return path;
    }

    c.drawPath(line((p) => p.expenses), _stroke(chartOrange));
    c.drawPath(line((p) => p.revenue), _stroke(chartBlue));
    for (final p in points) {
      final o = Offset(x(p.month), y(p.revenue));
      c.drawCircle(o, 4.5, Paint()..color = colors.surface);
      c.drawCircle(o, 3.2, Paint()..color = p.month <= 0 ? colors.ink : chartBlue);
    }
    final end = points.last;
    _text(c, 'Expenses, flat', Offset(l + pw + 8, y(end.expenses)), colors.ink, size: 11.5);
    _text(
      c,
      'Revenue, +${(d.monthlyGrowth * 100).toStringAsFixed(1)}%/mo',
      Offset(l + pw + 8, y(end.revenue)),
      colors.ink,
      size: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant RevenueChartPainter old) => old.d != d || old.colors != colors;
}

/// Cash in the bank, from the September close through the projection.
class CashChartPainter extends CustomPainter {
  CashChartPainter(this.d, this.colors);

  final DefaultAlive d;
  final ChartColors colors;

  @override
  void paint(Canvas c, Size size) {
    const l = 64.0, r = 132.0, t = 14.0, b = 34.0;
    final pw = size.width - l - r, ph = size.height - t - b;
    final points = [...d.history, ...d.projection];
    final first = points.first.month, last = points.last.month;
    final top = (points.map((p) => p.cash).reduce(math.max) / 1000000).ceil() * 1000000.0;
    double x(int m) => l + (m - first) / (last - first) * pw;
    double y(double v) => t + ph - math.max(v, 0) / top * ph;

    for (var v = 0.0; v <= top; v += 1000000) {
      c.drawLine(Offset(l, y(v)), Offset(l + pw, y(v)), _stroke(colors.grid, 1));
      _text(c, v == 0 ? '€0' : _eur(v), Offset(l - 8, y(v)), colors.label, align: TextAlign.right);
    }
    for (final p in points) {
      if ((p.month - first) % 3 == 0) {
        _text(c, monthLabel(p.month), Offset(x(p.month), size.height - 14), colors.label, align: TextAlign.center);
      }
    }
    final path = Path()..moveTo(x(points.first.month), y(points.first.cash));
    for (final p in points.skip(1)) {
      path.lineTo(x(p.month), y(p.cash));
    }
    c.drawPath(path, _stroke(chartBlue));
    for (final p in points) {
      final o = Offset(x(p.month), y(p.cash));
      c.drawCircle(o, 4, Paint()..color = colors.surface);
      c.drawCircle(o, 2.8, Paint()..color = p.month <= 0 ? colors.ink : chartBlue);
    }
    final low = d.projection[math.min(d.months, d.projection.length - 1)];
    final o = Offset(x(low.month), y(low.cash));
    c.drawCircle(o, 6, Paint()..color = colors.surface);
    c.drawCircle(o, 6, _stroke(colors.ink));
    _text(
      c,
      'Low point ${_eur(low.cash)}',
      o + const Offset(0, -16),
      colors.ink,
      align: TextAlign.center,
      weight: FontWeight.w600,
      size: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant CashChartPainter old) => old.d != d || old.colors != colors;
}

/// Default alive or dead for every steady monthly growth rate and net burn,
/// with October as a dot and the distance to the edge.
class AliveMapPainter extends CustomPainter {
  AliveMapPainter(this.d, this.colors);

  final DefaultAlive d;
  final ChartColors colors;

  @override
  void paint(Canvas c, Size size) {
    const l = 74.0, r = 20.0, t = 14.0, b = 42.0;
    const gmax = 0.25, bmin = 150000.0, bmax = 350000.0;
    final pw = size.width - l - r, ph = size.height - t - b;
    double x(double g) => l + math.min(g, gmax) / gmax * pw;
    double y(double v) => t + ph - (v - bmin) / (bmax - bmin) * ph;

    final edge = [for (final e in d.edge) Offset(x(e.growth), y(e.burn))];
    if (edge.isEmpty) return;
    final dead = Path()..moveTo(l, y(bmin));
    for (final p in edge) {
      dead.lineTo(p.dx, p.dy);
    }
    dead
      ..lineTo(l, y(bmax))
      ..close();
    final alive = Path()..moveTo(edge.first.dx, edge.first.dy);
    for (final p in edge.skip(1)) {
      alive.lineTo(p.dx, p.dy);
    }
    alive
      ..lineTo(l + pw, y(bmax))
      ..lineTo(l + pw, y(bmin))
      ..close();
    c.drawPath(dead, Paint()..color = chartBad.withValues(alpha: 0.12));
    c.drawPath(alive, Paint()..color = chartGood.withValues(alpha: 0.14));
    final edgePath = Path()..moveTo(edge.first.dx, edge.first.dy);
    for (final p in edge.skip(1)) {
      edgePath.lineTo(p.dx, p.dy);
    }
    c.drawPath(edgePath, _stroke(colors.ink, 1.8));

    for (final g in [0.0, 0.05, 0.10, 0.15, 0.20, 0.25]) {
      _text(c, '${(g * 100).round()}%', Offset(x(g), t + ph + 14), colors.label, align: TextAlign.center);
    }
    _text(
      c,
      'Monthly ARR growth, held steady',
      Offset(l + pw / 2, size.height - 8),
      colors.ink,
      align: TextAlign.center,
      size: 11.5,
    );
    for (var v = bmin; v <= bmax; v += 50000) {
      _text(c, _eur(v), Offset(l - 8, y(v)), colors.label, align: TextAlign.right);
    }
    c.save();
    c.translate(12, t + ph / 2);
    c.rotate(-math.pi / 2);
    _text(c, 'Monthly net burn', Offset.zero, colors.ink, align: TextAlign.center, size: 11.5);
    c.restore();
    _text(c, 'DEFAULT DEAD', Offset(l + 12, t + 14), chartBad, weight: FontWeight.w700, size: 12.5);
    _text(
      c,
      'DEFAULT ALIVE',
      Offset(l + pw - 12, t + ph - 14),
      chartGood,
      weight: FontWeight.w700,
      size: 12.5,
      align: TextAlign.right,
    );

    final cy = y(d.burn.clamp(bmin, bmax));
    final cx = x(d.monthlyGrowth), ex = x(d.minGrowth);
    _dashedLine(c, Offset(ex, cy), Offset(cx, cy), _stroke(colors.ink, 1.2), dash: 3);
    c.drawCircle(Offset(ex, cy), 5, Paint()..color = colors.surface);
    c.drawCircle(Offset(ex, cy), 5, _stroke(colors.ink));
    _text(
      c,
      'edge ${(d.minGrowth * 100).toStringAsFixed(1)}%',
      Offset(ex - 10, cy + 16),
      colors.ink,
      align: TextAlign.right,
      size: 11.5,
    );
    c.drawCircle(Offset(cx, cy), 7.5, Paint()..color = colors.surface);
    c.drawCircle(Offset(cx, cy), 6, Paint()..color = colors.ink);
    _text(
      c,
      'October: ${(d.monthlyGrowth * 100).toStringAsFixed(1)}%, ${_eur(d.burn)} burn',
      Offset(cx + 12, cy - 12),
      colors.ink,
      weight: FontWeight.w700,
      size: 12,
    );
  }

  @override
  bool shouldRepaint(covariant AliveMapPainter old) => old.d != d || old.colors != colors;
}

/// How ARR got from September to October: start, each deal and loss, end.
class BridgeChartPainter extends CustomPainter {
  BridgeChartPainter(this.bridge, this.colors);

  final ArrBridge bridge;
  final ChartColors colors;

  static const rowH = 30.0;
  static double heightFor(ArrBridge b) => (b.rows.length + 2) * rowH + 26;

  @override
  void paint(Canvas c, Size size) {
    const l = 230.0, r = 70.0, t = 4.0;
    final rows = [
      ('September ARR', bridge.start, 0),
      for (final row in bridge.rows) (row.lost ? '${row.name} (lost)' : row.name, row.arr, row.lost ? -1 : 1),
      ('October ARR', bridge.end, 0),
    ];
    final vmin = (math.min(bridge.start, bridge.end) * 0.85 / 20000).floor() * 20000.0;
    final vmax = (bridge.end * 1.02 / 20000).ceil() * 20000.0;
    final pw = size.width - l - r;
    double x(double v) => l + (v - vmin) / (vmax - vmin) * pw;
    final bottom = t + rowH * rows.length;
    for (var v = vmin; v <= vmax; v += 20000) {
      c.drawLine(Offset(x(v), t), Offset(x(v), bottom), _stroke(colors.grid, 1));
      _text(c, _eur(v), Offset(x(v), size.height - 10), colors.label, align: TextAlign.center);
    }
    var run = 0.0;
    for (final (i, (label, v, kind)) in rows.indexed) {
      final yy = t + i * rowH + 5;
      double a, z;
      Color col;
      String txt;
      if (kind == 0) {
        a = vmin;
        z = v;
        col = chartBlue;
        txt = _eur(v);
        run = v;
      } else {
        a = math.min(run, run + v);
        z = math.max(run, run + v);
        col = kind > 0 ? chartGood : chartBad;
        txt = '${v > 0 ? '+' : '−'}${_eur(v.abs())}';
        run += v;
      }
      _text(c, label, Offset(l - 10, yy + 10), colors.ink, align: TextAlign.right, size: 12, maxWidth: l - 16);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x(a), yy, math.max(x(z) - x(a), 3), rowH - 10), const Radius.circular(3)),
        Paint()..color = col,
      );
      _text(
        c,
        txt,
        Offset(x(kind < 0 ? a : z) + (kind < 0 ? -7 : 7), yy + 10),
        colors.ink,
        weight: FontWeight.w600,
        size: 11.5,
        align: kind < 0 ? TextAlign.right : TextAlign.left,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BridgeChartPainter old) => old.bridge != bridge || old.colors != colors;
}

/// Demos booked per week, with the lowest week called out.
class DemosChartPainter extends CustomPainter {
  DemosChartPainter(this.weeks, this.colors);

  /// (label, demos) per week, oldest first.
  final List<(String, double)> weeks;
  final ChartColors colors;

  @override
  void paint(Canvas c, Size size) {
    if (weeks.isEmpty) return;
    const l = 34.0, t = 26.0, b = 26.0;
    final ph = size.height - t - b;
    final top = (weeks.map((w) => w.$2).reduce(math.max) / 25).ceil() * 25.0;
    final slot = (size.width - l - 6) / weeks.length;
    final bw = math.min(46.0, slot * 0.62);
    for (var v = 0.0; v <= top; v += 25) {
      final yy = t + ph - v / top * ph;
      c.drawLine(Offset(l, yy), Offset(size.width - 6, yy), _stroke(colors.grid, 1));
      _text(c, v.round().toString(), Offset(l - 6, yy), colors.label, align: TextAlign.right);
    }
    final lowest = weeks.map((w) => w.$2).reduce(math.min);
    for (final (i, (label, v)) in weeks.indexed) {
      final cx = l + slot * i + slot / 2;
      final bh = v / top * ph;
      final low = v == lowest && weeks.length > 1;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - bw / 2, t + ph - bh, bw, bh), const Radius.circular(4)),
        Paint()..color = low ? chartBad.withValues(alpha: 0.85) : chartBlue,
      );
      _text(
        c,
        v.round().toString(),
        Offset(cx, t + ph - bh - 9),
        colors.ink,
        align: TextAlign.center,
        weight: FontWeight.w600,
        size: 12,
      );
      _text(c, label, Offset(cx, size.height - 10), colors.label, align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant DemosChartPainter old) => old.weeks != weeks || old.colors != colors;
}

/// Renders a painter to PNG bytes, for the PDF export.
Future<List<int>> paintToPng(CustomPainter painter, Size size, {double pixelRatio = 3}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  painter.paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    (size.width * pixelRatio).round(),
    (size.height * pixelRatio).round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
