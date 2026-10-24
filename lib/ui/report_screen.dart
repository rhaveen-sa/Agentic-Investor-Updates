import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../models/fact.dart';
import '../models/report.dart';
import 'report_charts.dart';
import 'report_pdf.dart';
import 'widgets/common.dart';

final _numberRe = RegExp(
  r'[−+\-]?€?\d[\d.,]*(?:\s?(?:k|M|%| pts| months| stores| teams| clinics| demos| impressions))?',
);

/// Section titles as the investor reads them; the agent's keys stay the same.
String sectionHeading(String title) => switch (title) {
  'TL;DR' => 'In short',
  'Asks' => 'Ask',
  'Lowlights' => 'Challenges',
  _ => title,
};

ChartColors chartColors(BuildContext context) => ChartColors(
  ink: context.cs.foreground,
  label: context.cs.mutedForeground,
  grid: context.cs.border,
  surface: context.cs.card,
);

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.report;
    if (r == null) {
      return Column(
        children: [
          const ScreenHeader('Report'),
          Expanded(
            child: EmptyState(
              icon: LucideIcons.fileText,
              title: s.monthClosed ? 'October is closed' : 'Drafted when the month closes',
              action: s.monthClosed
                  ? ShadButton(
                      enabled: !s.isBusy,
                      onPressed: s.draftReport,
                      leading: const Icon(LucideIcons.fileText, size: 16),
                      child: const Text('Draft now'),
                    )
                  : null,
            ),
          ),
        ],
      );
    }
    final tt = context.tt;
    final section = {for (final sec in r.sections) sec.title: sec};
    Widget claims(String title) {
      final sec = section[title];
      return sec == null || keptClaims(sec).isEmpty ? const SizedBox.shrink() : _Section(sec);
    }

    final notCounted = r.allClaims.where((c) => c.flag != ClaimFlag.none).toList();
    final weeks = _demoWeeks(s);
    return Column(
      children: [
        ScreenHeader(
          'Report',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r.verified)
                notCounted.isEmpty
                    ? const TintBadge('All claims verified', green, icon: LucideIcons.shieldCheck)
                    : TintBadge(
                        '${notCounted.length} claim${notCounted.length == 1 ? '' : 's'} not counted',
                        amber,
                        icon: LucideIcons.flag,
                      ),
              const SizedBox(width: 10),
              ShadButton.outline(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: reportAsText(r)));
                  toast(context, 'Update copied as text');
                },
                leading: const Icon(LucideIcons.copy, size: 16),
                child: const Text('Copy'),
              ),
              const SizedBox(width: 6),
              ShadButton.outline(
                onPressed: () => downloadReportPdf(context, s, r),
                leading: const Icon(LucideIcons.download, size: 16),
                child: const Text('Download PDF'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ShadCard(
                  radius: BorderRadius.circular(rLg),
                  padding: const EdgeInsets.fromLTRB(44, 36, 44, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AppLogo(size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RESON8 · INVESTOR UPDATE',
                                  style: tt.small.copyWith(color: chartOrange, letterSpacing: 1.4, fontSize: 11.5),
                                ),
                                Text('October 2026', style: tt.h2.copyWith(letterSpacing: -0.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To Balderton Capital, NP-Hard and angels · From Thomas · Month closed 31 October 2026',
                        style: tt.muted.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 22),
                      if (section['TL;DR'] != null && keptClaims(section['TL;DR']!).isNotEmpty)
                        _Box(tint: true, child: _Section(section['TL;DR']!, spacing: 0)),
                      if (section['Asks'] != null && keptClaims(section['Asks']!).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Box(accent: true, child: _Section(section['Asks']!, spacing: 0)),
                      ],
                      const _Heading('Key numbers'),
                      _KpiTable(r.kpis),
                      if (r.defaultAlive != null) ...[
                        const _Heading('Default alive or default dead?'),
                        _DefaultAliveBlock(r.defaultAlive!),
                      ],
                      if (r.bridge != null && r.bridge!.rows.isNotEmpty) ...[
                        const _Heading('Customers'),
                        _CustomersBlock(r.bridge!),
                      ],
                      if (notCounted.isNotEmpty) ...[
                        const _Heading('Pipeline we are not counting yet'),
                        _NotCounted(notCounted),
                      ],
                      claims('Highlights'),
                      if (weeks.length > 1) ...[
                        _Caption('Demos booked per week'),
                        SizedBox(
                          height: 170,
                          width: 360,
                          child: CustomPaint(painter: DemosChartPainter(weeks, chartColors(context))),
                        ),
                        const SizedBox(height: 22),
                      ],
                      claims('Lowlights'),
                      claims('Product'),
                      claims('Team'),
                      claims('Next month'),
                      Text('Thanks for your support,\nThomas', style: tt.p.copyWith(height: 1.6)),
                      const _Heading('Sources'),
                      _SourcesTable(citedFacts(s, r)),
                      const SizedBox(height: 24),
                      const ShadSeparator.horizontal(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Spacer(),
                          if (r.approved)
                            const TintBadge('Sent to investors', green, icon: LucideIcons.check)
                          else
                            ShadButton(
                              size: ShadButtonSize.lg,
                              onPressed: s.approveReport,
                              leading: const Icon(LucideIcons.send, size: 16),
                              child: const Text('Approve & send'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Claims that made it through the verifier; flagged ones stay out of the counted update.
List<Claim> keptClaims(ReportSection sec) => sec.claims.where((c) => c.flag == ClaimFlag.none).toList();

/// Confirmed weekly demo bookings, oldest first.
List<(String, double)> _demoWeeks(AppState s) {
  final facts =
      s.facts.where((f) => f.metric == 'demos_week' && f.status == FactStatus.confirmed && f.value != null).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  return [for (final f in facts) (shortDate.format(f.date), f.value!)];
}

/// Every fact the update relies on: claims, key numbers, default alive and customers.
List<Fact> citedFacts(AppState s, Report r) {
  final ids = <String>{
    for (final c in r.allClaims.where((c) => c.flag == ClaimFlag.none)) ...c.factIds,
    for (final k in r.kpis) ...[?k.prevFactId, ?k.currFactId],
    ...?r.defaultAlive?.factIds,
    if (r.bridge != null) ...[r.bridge!.startFactId, r.bridge!.endFactId, for (final row in r.bridge!.rows) row.factId],
  };
  final seen = <String>{};
  return [
    for (final id in ids)
      if (s.factById(id) case final f? when seen.add('${f.sourceRef}|${f.text}')) f,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.cs.border, width: 2)),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.tt.small.copyWith(letterSpacing: 1.3, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: context.tt.small.copyWith(fontSize: 13)),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.tint = false, this.accent = false});

  final Widget child;
  final bool tint;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
    decoration: BoxDecoration(
      color: tint ? context.cs.muted.withValues(alpha: 0.6) : null,
      borderRadius: BorderRadius.circular(rMd),
      border: accent ? Border.all(color: chartOrange, width: 1.6) : null,
    ),
    child: child,
  );
}

class _Section extends StatelessWidget {
  const _Section(this.sec, {this.spacing = 22});

  final ReportSection sec;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final numbered = sec.title == 'Asks' || sec.title == 'Next month';
    final heading = sectionHeading(sec.title);
    final boxed = sec.title == 'TL;DR' || sec.title == 'Asks';
    return Padding(
      padding: EdgeInsets.only(bottom: spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (boxed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(heading, style: context.tt.large),
            )
          else
            _Heading(heading),
          for (final (i, c) in keptClaims(sec).indexed) _ClaimLine(c, bullet: numbered ? '${i + 1}.' : '•'),
        ],
      ),
    );
  }
}

class _ClaimLine extends StatelessWidget {
  const _ClaimLine(this.c, {required this.bullet});

  final Claim c;
  final String bullet;

  @override
  Widget build(BuildContext context) {
    final base = context.tt.p.copyWith(fontSize: 15, height: 1.6);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _numberRe.allMatches(c.text)) {
      final before = c.text.substring(0, m.start).toLowerCase();
      if (before.endsWith('release ') || before.endsWith('releases ') || before.endsWith('week ')) continue;
      // Part of a word like p95 or v2, not a figure.
      if (before.isNotEmpty && RegExp(r'[a-z]$').hasMatch(before)) continue;
      if (m.start > last) spans.add(TextSpan(text: c.text.substring(last, m.start)));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _NumberLink(text: m.group(0)!, factIds: c.factIds, style: base),
        ),
      );
      last = m.end;
    }
    if (last < c.text.length) spans.add(TextSpan(text: c.text.substring(last)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text(bullet, style: base)),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => showFactSources(context, c.factIds, title: 'Sources for this claim'),
                child: Text.rich(TextSpan(style: base, children: spans)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberLink extends StatelessWidget {
  const _NumberLink({required this.text, required this.factIds, required this.style});

  final String text;
  final List<String> factIds;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showFactSources(context, factIds, title: 'Source for $text'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(
            text,
            style: style.copyWith(color: blue, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// A figure that opens its source when clicked.
class _SourceValue extends StatelessWidget {
  const _SourceValue(this.text, this.factIds, {this.bold = false, this.color});

  final String text;
  final List<String> factIds;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.tt.small.copyWith(
      fontSize: 14,
      color: color ?? blue,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showFactSources(context, factIds, title: 'Source for $text'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: style),
        ),
      ),
    );
  }
}

class _TableFrame extends StatelessWidget {
  const _TableFrame({required this.header, required this.rows, required this.widths});

  final List<String> header;
  final List<List<Widget>> rows;
  final Map<int, TableColumnWidth> widths;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final head = context.tt.muted.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: w);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(rMd),
      ),
      child: Table(
        columnWidths: widths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(horizontalInside: BorderSide(color: cs.border)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: cs.muted.withValues(alpha: 0.5)),
            children: [for (final h in header) pad(Text(h, style: head))],
          ),
          for (final r in rows) TableRow(children: [for (final w in r) pad(w)]),
        ],
      ),
    );
  }
}

class _KpiTable extends StatelessWidget {
  const _KpiTable(this.rows);

  final List<KpiRow> rows;

  @override
  Widget build(BuildContext context) {
    final body = context.tt.small.copyWith(fontWeight: FontWeight.w400, fontSize: 14);
    final muted = body.copyWith(color: context.cs.mutedForeground);
    Widget value(String? v, String? id, {bool bold = false}) => v == null
        ? Text('n/a', style: muted)
        : id == null
        ? Text(v, style: body)
        : Align(
            alignment: Alignment.centerLeft,
            child: _SourceValue(v, [id], bold: bold),
          );
    return _TableFrame(
      header: const ['Metric', 'September', 'October', 'Change'],
      widths: const {
        0: FlexColumnWidth(2.4),
        1: FlexColumnWidth(1.3),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.3),
      },
      rows: [
        for (final r in rows)
          [
            Text(r.label, style: body),
            value(r.prev, r.prevFactId),
            value(r.curr, r.currFactId, bold: true),
            Text(r.change ?? '', style: muted),
          ],
      ],
    );
  }
}

String _pct(double g) => '${(g * 100).toStringAsFixed(1)}%';

/// The answer in one line, shared by the screen and the exports.
String defaultAliveVerdict(DefaultAlive d) {
  final g = _pct(d.monthlyGrowth);
  if (d.alive) {
    return 'Default alive. If costs stay flat and ARR keeps growing $g a month, revenue covers costs in '
        '${monthLabel(d.months)} (${d.months} months), with ${AppState.formatValue(d.cashLeft, 'EUR')} still in the bank.';
  }
  if (d.months >= 120) return 'Default dead. At $g monthly growth, revenue does not cover costs within ten years.';
  return 'Default dead. At $g monthly growth the cash runs out in ${d.months} months, before revenue covers costs.';
}

/// The growth rate where the answer flips, and how far burn could rise.
String defaultAliveThreshold(DefaultAlive d) => d.alive
    ? 'The edge is ${_pct(d.minGrowth)} a month: growth can roughly halve before we are default dead. At today\'s '
          'growth, net burn could rise to about ${AppState.formatValue((d.maxBurn / 1000).round() * 1000.0, 'EUR')} '
          'a month before it flips.'
    : 'It takes at least ${_pct(d.minGrowth)} monthly growth to become default alive.';

class _DefaultAliveBlock extends StatelessWidget {
  const _DefaultAliveBlock(this.d);

  final DefaultAlive d;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final colors = chartColors(context);
    final verdictColor = d.alive ? green : red;
    final body = tt.p.copyWith(fontSize: 14.5, height: 1.55);
    final rows = [
      for (final p in d.projection)
        if (p.month % 3 == 0 || p.month == d.months) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: verdictColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(rMd),
            border: Border.all(color: verdictColor, width: 1.6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.alive ? '✓ Default alive' : '✕ Default dead',
                style: tt.h4.copyWith(color: verdictColor, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(defaultAliveVerdict(d), style: body),
                    const SizedBox(height: 4),
                    Text(defaultAliveThreshold(d), style: body),
                    const SizedBox(height: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => showFactSources(context, d.factIds, title: 'Inputs for the default alive test'),
                        child: Text('Show the inputs', style: tt.small.copyWith(color: blue, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _Caption('Monthly revenue against monthly expenses, from the September close'),
        Row(
          children: [
            _LegendDot(chartBlue, 'Revenue (ARR ÷ 12)'),
            const SizedBox(width: 16),
            _LegendDot(chartOrange, 'Expenses (net burn + revenue), held flat'),
            const SizedBox(width: 16),
            _LegendDot(cs.foreground, 'Actual close'),
          ],
        ),
        SizedBox(
          height: 260,
          width: double.infinity,
          child: CustomPaint(painter: RevenueChartPainter(d, colors)),
        ),
        const _Caption('Cash in the bank'),
        SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(painter: CashChartPainter(d, colors)),
        ),
        const _Caption('Dead or alive map: where October puts us, and how far we are from the edge'),
        SizedBox(
          height: 290,
          width: double.infinity,
          child: CustomPaint(painter: AliveMapPainter(d, colors)),
        ),
        Text(
          'Each point is a steady monthly growth rate and a monthly net burn, starting from October\'s ARR and '
          '${AppState.formatValue(d.cash, 'EUR')} cash. Left of the line, the cash runs out first.',
          style: tt.muted.copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        _TableFrame(
          header: const ['Month', 'Revenue / mo', 'Expenses / mo', 'Cash'],
          widths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
          rows: [
            for (final p in rows)
              [
                Text(
                  monthLabel(p.month),
                  style: tt.small.copyWith(fontSize: 14, fontWeight: p.month == d.months ? FontWeight.w700 : null),
                ),
                for (final v in [p.revenue, p.expenses, p.cash])
                  Text(
                    AppState.formatValue(v, 'EUR'),
                    style: tt.small.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                  ),
              ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'A projection, not a forecast: it assumes October\'s growth holds and costs stay flat. Computed in code from '
          'the confirmed facts.',
          style: tt.muted.copyWith(fontSize: 12.5),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.tt.muted.copyWith(fontSize: 12)),
    ],
  );
}

class _CustomersBlock extends StatelessWidget {
  const _CustomersBlock(this.b);

  final ArrBridge b;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final body = tt.small.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
    final won = b.rows.where((r) => !r.lost).toList();
    final teams = won.fold(0, (n, r) => n + r.name.split(', ').length);
    final lost = b.rows.where((r) => r.lost).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$teams new paying team${teams == 1 ? '' : 's'} and $lost loss${lost == 1 ? '' : 'es'}.',
          style: tt.p.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 10),
        _TableFrame(
          header: const ['Customer', 'Deal', 'ARR'],
          widths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1.6), 2: FlexColumnWidth(1)},
          rows: [
            for (final r in b.rows)
              [
                Text(r.lost ? '${r.name} (lost)' : r.name, style: body.copyWith(fontWeight: FontWeight.w600)),
                Text(r.detail, style: body),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SourceValue(
                    '${r.arr > 0 ? '+' : '−'}${AppState.formatValue(r.arr.abs(), 'EUR')}',
                    [r.factId],
                    color: r.lost ? red : green,
                    bold: true,
                  ),
                ),
              ],
          ],
        ),
        const _Caption('How ARR got from September to October'),
        SizedBox(
          height: BridgeChartPainter.heightFor(b),
          width: double.infinity,
          child: CustomPaint(painter: BridgeChartPainter(b, chartColors(context))),
        ),
        if (!b.reconciles)
          Text(
            'The bridge does not add up to October ARR. Check the customer facts.',
            style: tt.small.copyWith(color: red),
          ),
      ],
    );
  }
}

/// Claims the verifier would not count: said in a meeting, not in any number.
class _NotCounted extends StatelessWidget {
  const _NotCounted(this.claims);

  final List<Claim> claims;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(rMd),
        border: Border(left: BorderSide(color: amber, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in claims) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => showFactSources(context, c.factIds, title: 'Sources for this claim'),
                child: Text(c.text, style: tt.p.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            Text(
              '${c.flagReason ?? 'Not backed by a confirmed fact.'} Not included in any number above.',
              style: tt.muted.copyWith(fontSize: 13),
            ),
            if (c != claims.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SourcesTable extends StatelessWidget {
  const _SourcesTable(this.facts);

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final body = tt.small.copyWith(fontSize: 13, fontWeight: FontWeight.w400);
    return _TableFrame(
      header: const ['Source', 'Record', 'Date', 'Fact'],
      widths: const {0: FixedColumnWidth(130), 1: FixedColumnWidth(150), 2: FixedColumnWidth(70), 3: FlexColumnWidth()},
      rows: [
        for (final f in facts)
          [
            Align(
              alignment: Alignment.centerLeft,
              child: SourceBadge(f.sourceId, onTap: () => showFactSources(context, [f.id])),
            ),
            Text(f.sourceRef, style: body.copyWith(fontFamily: 'Menlo', fontSize: 12)),
            Text(shortDate.format(f.date), style: body),
            Text(f.text, style: body),
          ],
      ],
    );
  }
}

/// Plain-text version for the Copy button.
String reportAsText(Report r) {
  final section = {for (final sec in r.sections) sec.title: sec};
  final b = StringBuffer('Subject: ${r.subject}\n\nHi all,\n\n');
  void claims(String title) {
    final sec = section[title];
    if (sec == null) return;
    final kept = keptClaims(sec);
    if (kept.isEmpty) return;
    b.writeln(sectionHeading(title));
    for (var i = 0; i < kept.length; i++) {
      b.writeln('${title == 'Asks' || title == 'Next month' ? '${i + 1}.' : '-'} ${kept[i].text}');
    }
    b.writeln();
  }

  claims('TL;DR');
  claims('Asks');
  b.writeln('${'Key numbers'.padRight(26)}${'Sep'.padRight(11)}${'Oct'.padRight(11)}Change');
  for (final k in r.kpis) {
    b.writeln(
      '${k.label.padRight(26)}${(k.prev ?? 'n/a').padRight(11)}${(k.curr ?? 'n/a').padRight(11)}${k.change ?? ''}',
    );
  }
  b.writeln();
  final d = r.defaultAlive;
  if (d != null) {
    b.writeln('Default alive or default dead?');
    b.writeln('- ${defaultAliveVerdict(d)}');
    b.writeln('- ${defaultAliveThreshold(d)}');
    b.writeln();
  }
  final bridge = r.bridge;
  if (bridge != null && bridge.rows.isNotEmpty) {
    b.writeln('Customers');
    for (final row in bridge.rows) {
      b.writeln(
        '- ${row.lost ? '${row.name} (lost)' : row.name}: ${row.arr > 0 ? '+' : '−'}${AppState.formatValue(row.arr.abs(), 'EUR')} ARR',
      );
    }
    b.writeln();
  }
  for (final t in ['Highlights', 'Lowlights', 'Product', 'Team', 'Next month']) {
    claims(t);
  }
  b.write('Thanks for your support,\nThomas');
  return b.toString();
}
