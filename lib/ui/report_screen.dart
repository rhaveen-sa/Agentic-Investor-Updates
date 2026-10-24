import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_state.dart';
import '../models/report.dart';
import 'widgets/common.dart';

final _numberRe = RegExp(r'[−+\-]?€?\d[\d.,]*(?:\s?(?:k|M|%| pts| months| stores| demos| impressions))?');

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.report;
    if (r == null) {
      return Column(children: [
        const ScreenHeader('Report'),
        Expanded(
          child: EmptyState(
            icon: LucideIcons.mail,
            title: s.monthClosed ? 'October is closed' : 'Drafted when the month closes',
            action: s.monthClosed
                ? ShadButton(
                    enabled: !s.isBusy,
                    onPressed: s.draftReport,
                    leading: const Icon(LucideIcons.sparkles, size: 16),
                    child: const Text('Draft now'),
                  )
                : null,
          ),
        ),
      ]);
    }
    final tt = context.tt;
    return Column(children: [
      ScreenHeader(
        'Report',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (r.verified)
            r.flaggedCount == 0
                ? const TintBadge('All claims verified', green, icon: LucideIcons.shieldCheck)
                : TintBadge('${r.flaggedCount} flagged', amber, icon: LucideIcons.flag),
          const SizedBox(width: 10),
          ShadButton.outline(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportAsText(r)));
              toast(context, 'Update copied as text');
            },
            leading: const Icon(LucideIcons.copy, size: 16),
            child: const Text('Copy'),
          ),
        ]),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Meta('To', 'Northstar Ventures, 5 angels'),
                  const SizedBox(height: 10),
                  Text(r.subject, style: tt.h3),
                  const SizedBox(height: 18),
                  const ShadSeparator.horizontal(),
                  const SizedBox(height: 18),
                  Text('Hi all,', style: tt.p),
                  const SizedBox(height: 18),
                  for (final sec in r.sections) ...[
                    if (sec.title == 'Highlights') ...[_KpiTable(r.kpis), const SizedBox(height: 22)],
                    _Section(sec),
                  ],
                  Text('Thanks for your support,\nLena', style: tt.p.copyWith(height: 1.6)),
                  const SizedBox(height: 28),
                  const ShadSeparator.horizontal(),
                  const SizedBox(height: 18),
                  Row(children: [
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
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          SizedBox(width: 48, child: Text(k, style: context.tt.muted.copyWith(fontSize: 13))),
          Text(v, style: context.tt.small.copyWith(fontWeight: FontWeight.w400)),
        ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sec.title, style: context.tt.large),
        const SizedBox(height: 8),
        for (var i = 0; i < sec.claims.length; i++) _ClaimLine(sec.claims[i], bullet: numbered ? '${i + 1}.' : '•'),
      ]),
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
      if (m.start > last) spans.add(TextSpan(text: c.text.substring(last, m.start)));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _NumberLink(text: m.group(0)!, factIds: c.factIds, style: base),
      ));
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ]),
        if (flagged)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.flag, size: 13, color: flagColor)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(c.flagReason ?? 'Check this claim',
                    style: tt.small.copyWith(color: flagColor, fontSize: 12.5)),
              ),
            ]),
          ),
      ]),
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
          child: Text(text, style: style.copyWith(color: blue, fontWeight: FontWeight.w600)),
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
              ? Text('–', style: body.copyWith(color: cs.mutedForeground))
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
                            decoration: BoxDecoration(color: blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                            child: Text(v, style: body.copyWith(color: blue, fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
                          ),
                        ),
                      ),
                    ),
        );
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: w);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('KPIs', style: tt.large),
      const SizedBox(height: 8),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(rMd)),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(2.4), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.3), 3: FlexColumnWidth(1.3)},
          border: TableBorder(horizontalInside: BorderSide(color: cs.border)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: cs.muted.withValues(alpha: 0.5)),
              children: [
                pad(Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text('Metric', style: head))),
                pad(Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text('Sep', style: head))),
                pad(Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text('Oct', style: head))),
                pad(Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text('Change', style: head))),
              ],
            ),
            for (final r in rows)
              TableRow(children: [
                pad(Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text(r.label, style: body))),
                pad(cell(r.prev, r.prevFactId)),
                pad(cell(r.curr, r.currFactId, bold: true)),
                pad(Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(r.change ?? '', style: body.copyWith(color: cs.mutedForeground)),
                )),
              ]),
          ],
        ),
      ),
    ]);
  }
}

String reportAsText(Report r) {
  final b = StringBuffer('Subject: ${r.subject}\n\nHi all,\n\n');
  for (final sec in r.sections) {
    if (sec.title == 'Highlights') {
      b.writeln('${'KPIs'.padRight(26)}${'Sep'.padRight(11)}${'Oct'.padRight(11)}Change');
      for (final k in r.kpis) {
        b.writeln('${k.label.padRight(26)}${(k.prev ?? '–').padRight(11)}${(k.curr ?? '–').padRight(11)}${k.change ?? ''}');
      }
      b.writeln();
    }
    b.writeln(sec.title);
    for (var i = 0; i < sec.claims.length; i++) {
      b.writeln('${sec.title == 'Asks' ? '${i + 1}.' : '-'} ${sec.claims[i].text}');
    }
    b.writeln();
  }
  b.write('Thanks for your support,\nLena');
  return b.toString();
}
