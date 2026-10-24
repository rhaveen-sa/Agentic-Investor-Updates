import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../models/report.dart';
import 'widgets/common.dart';

final _numberRe = RegExp(
  r'[−+\-]?€?\d[\d.,]*(?:\s?(?:k|M|%| pts| months| stores| teams| clinics| demos| impressions))?',
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
              icon: LucideIcons.mail,
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
    return Column(
      children: [
        ScreenHeader(
          'Report',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r.verified)
                r.flaggedCount == 0
                    ? const TintBadge('All claims verified', green, icon: LucideIcons.shieldCheck)
                    : TintBadge(
                        '${r.flaggedCount} claim${r.flaggedCount == 1 ? '' : 's'} removed',
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
                onPressed: () => _download(context, r),
                leading: const Icon(LucideIcons.download, size: 16),
                child: const Text('Download'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShadCard(
                      radius: BorderRadius.circular(rLg),
                      padding: const EdgeInsets.fromLTRB(44, 36, 44, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Meta('To', 'Balderton Capital, NP-Hard, angels'),
                          const SizedBox(height: 10),
                          Text(r.subject, style: tt.h3),
                          const SizedBox(height: 18),
                          const ShadSeparator.horizontal(),
                          const SizedBox(height: 18),
                          Text('Hi all,', style: tt.p),
                          const SizedBox(height: 18),
                          for (final sec in r.sections) ...[
                            if (sec.title == 'Highlights') ...[
                              _KpiTable(r.kpis),
                              const SizedBox(height: 22),
                              if (r.defaultAlive != null) ...[
                                _DefaultAliveBlock(r.defaultAlive!),
                                const SizedBox(height: 22),
                              ],
                            ],
                            if (keptClaims(sec).isNotEmpty) _Section(sec),
                          ],
                          Text('Thanks for your support,\nThomas', style: tt.p.copyWith(height: 1.6)),
                          const SizedBox(height: 28),
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
                    if (r.flaggedCount > 0) _RemovedClaims(r.allClaims.where((c) => c.flag != ClaimFlag.none).toList()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Claims that made it through the verifier; flagged ones stay out of the update.
List<Claim> keptClaims(ReportSection sec) => sec.claims.where((c) => c.flag == ClaimFlag.none).toList();

Future<void> _download(BuildContext context, Report r) async {
  final name = '${r.subject.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.md';
  try {
    final loc = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: ['md']),
      ],
    );
    if (loc == null) return;
    await XFile.fromData(utf8.encode(reportAsMarkdown(r)), mimeType: 'text/markdown', name: name).saveTo(loc.path);
    if (context.mounted) toast(context, 'Saved $name');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not save the file: $e');
  }
}

/// What the verifier took out, shown below the email but never sent.
class _RemovedClaims extends StatelessWidget {
  const _RemovedClaims(this.claims);

  final List<Claim> claims;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rLg),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.flag, size: 15, color: amber),
              const SizedBox(width: 8),
              Text('Removed by the verifier', style: tt.small),
            ],
          ),
          for (final c in claims) ...[
            const SizedBox(height: 10),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => showFactSources(context, c.factIds, title: 'Sources for this claim'),
                child: Text(
                  c.text,
                  style: tt.p.copyWith(
                    fontSize: 14,
                    height: 1.5,
                    decoration: TextDecoration.lineThrough,
                    color: cs.mutedForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              c.flagReason ?? 'Not backed by a confirmed fact.',
              style: tt.muted.copyWith(fontSize: 12.5, color: amber),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        SizedBox(width: 48, child: Text(k, style: context.tt.muted.copyWith(fontSize: 13))),
        Text(v, style: context.tt.small.copyWith(fontWeight: FontWeight.w400)),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.sec);

  final ReportSection sec;

  @override
  Widget build(BuildContext context) {
    final numbered = sec.title == 'Asks';
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sec.title, style: context.tt.large),
          const SizedBox(height: 8),
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
    final tt = context.tt;
    final base = tt.p.copyWith(fontSize: 15, height: 1.6);
    final flagged = c.flag != ClaimFlag.none;
    final flagColor = c.flag == ClaimFlag.unsupported ? red : amber;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: flagged ? const EdgeInsets.fromLTRB(10, 6, 10, 8) : const EdgeInsets.symmetric(vertical: 1),
      decoration: flagged
          ? BoxDecoration(
              color: flagColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(rSm),
              border: Border.all(color: flagColor.withValues(alpha: 0.35)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (flagged)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.flag, size: 13, color: flagColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.flagReason ?? 'Check this claim',
                      style: tt.small.copyWith(color: flagColor, fontSize: 12.5),
                    ),
                  ),
                ],
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

class _KpiTable extends StatelessWidget {
  const _KpiTable(this.rows);

  final List<KpiRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final head = tt.muted.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
    final body = tt.small.copyWith(fontWeight: FontWeight.w400, fontSize: 14);
    Widget cell(String? v, String? factId, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: v == null
          ? Text('n/a', style: body.copyWith(color: cs.mutedForeground))
          : factId == null
          ? Text(v, style: body)
          : Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => showFactSources(context, [factId], title: 'Source for $v'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      v,
                      style: body.copyWith(color: blue, fontWeight: bold ? FontWeight.w600 : FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
    );
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KPIs', style: tt.large),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: cs.border),
            borderRadius: BorderRadius.circular(rMd),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.4),
              1: FlexColumnWidth(1.3),
              2: FlexColumnWidth(1.3),
              3: FlexColumnWidth(1.3),
            },
            border: TableBorder(horizontalInside: BorderSide(color: cs.border)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.muted.withValues(alpha: 0.5)),
                children: [
                  pad(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text('Metric', style: head),
                    ),
                  ),
                  pad(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text('Sep', style: head),
                    ),
                  ),
                  pad(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text('Oct', style: head),
                    ),
                  ),
                  pad(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text('Change', style: head),
                    ),
                  ),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    pad(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Text(r.label, style: body),
                      ),
                    ),
                    pad(cell(r.prev, r.prevFactId)),
                    pad(cell(r.curr, r.currFactId, bold: true)),
                    pad(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Text(r.change ?? '', style: body.copyWith(color: cs.mutedForeground)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _pct(double g) => '${(g * 100).toStringAsFixed(1)}%';

/// The answer in one line, shared by the screen and the text export.
String defaultAliveVerdict(DefaultAlive d) {
  final g = _pct(d.monthlyGrowth);
  if (d.alive) {
    return 'Default alive. If costs stay flat and ARR keeps growing $g a month, revenue covers costs in '
        '${d.months} months, with ${AppState.formatValue(d.cashLeft, 'EUR')} still in the bank.';
  }
  if (d.months >= 120) return 'Default dead. At $g monthly growth, revenue does not cover costs within ten years.';
  return 'Default dead. At $g monthly growth the cash runs out in ${d.months} months, before revenue covers costs.';
}

/// The growth rate where the answer flips.
String defaultAliveThreshold(DefaultAlive d) => d.alive
    ? 'The line is ${_pct(d.minGrowth)} a month. Grow slower than that and the answer flips to default dead.'
    : 'It takes at least ${_pct(d.minGrowth)} monthly growth to become default alive.';

class _DefaultAliveBlock extends StatelessWidget {
  const _DefaultAliveBlock(this.d);

  final DefaultAlive d;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final body = tt.p.copyWith(fontSize: 15, height: 1.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Default alive?', style: tt.large),
            const SizedBox(width: 10),
            TintBadge(
              d.alive ? 'Default alive' : 'Default dead',
              d.alive ? green : red,
              icon: d.alive ? LucideIcons.circleCheck : LucideIcons.flag,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: cs.border),
            borderRadius: BorderRadius.circular(rMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(defaultAliveVerdict(d), style: body),
              const SizedBox(height: 4),
              Text(defaultAliveThreshold(d), style: body),
              const SizedBox(height: 10),
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
    );
  }
}

String reportAsText(Report r) {
  final b = StringBuffer('Subject: ${r.subject}\n\nHi all,\n\n');
  for (final sec in r.sections) {
    if (sec.title == 'Highlights') {
      b.writeln('${'KPIs'.padRight(26)}${'Sep'.padRight(11)}${'Oct'.padRight(11)}Change');
      for (final k in r.kpis) {
        b.writeln(
          '${k.label.padRight(26)}${(k.prev ?? 'n/a').padRight(11)}${(k.curr ?? 'n/a').padRight(11)}${k.change ?? ''}',
        );
      }
      b.writeln();
      final d = r.defaultAlive;
      if (d != null) {
        b.writeln('Default alive?');
        b.writeln('- ${defaultAliveVerdict(d)}');
        b.writeln('- ${defaultAliveThreshold(d)}');
        b.writeln();
      }
    }
    final claims = keptClaims(sec);
    if (claims.isEmpty) continue;
    b.writeln(sec.title);
    for (var i = 0; i < claims.length; i++) {
      b.writeln('${sec.title == 'Asks' ? '${i + 1}.' : '-'} ${claims[i].text}');
    }
    b.writeln();
  }
  b.write('Thanks for your support,\nThomas');
  return b.toString();
}

/// Markdown version of the update for the download button.
String reportAsMarkdown(Report r) {
  final b = StringBuffer('# ${r.subject}\n\nHi all,\n\n');
  for (final sec in r.sections) {
    if (sec.title == 'Highlights') {
      b.writeln('## KPIs\n');
      b.writeln('| Metric | Sep | Oct | Change |');
      b.writeln('| --- | --- | --- | --- |');
      for (final k in r.kpis) {
        b.writeln('| ${k.label} | ${k.prev ?? 'n/a'} | ${k.curr ?? 'n/a'} | ${k.change ?? ''} |');
      }
      b.writeln();
      final d = r.defaultAlive;
      if (d != null) {
        b.writeln('## Default alive?\n');
        b.writeln('${defaultAliveVerdict(d)} ${defaultAliveThreshold(d)}\n');
      }
    }
    final claims = keptClaims(sec);
    if (claims.isEmpty) continue;
    b.writeln('## ${sec.title}\n');
    for (var i = 0; i < claims.length; i++) {
      b.writeln('${sec.title == 'Asks' ? '${i + 1}.' : '-'} ${claims[i].text}');
    }
    b.writeln();
  }
  b.write('Thanks for your support,  \nThomas\n');
  return b.toString();
}
