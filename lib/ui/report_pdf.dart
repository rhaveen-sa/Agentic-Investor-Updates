import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' show BuildContext, CustomPainter, Size;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app_state.dart';
import '../models/fact.dart';
import '../models/report.dart';
import 'report_charts.dart';
import 'report_screen.dart';
import 'widgets/common.dart';

// The investor update as an A4 PDF: real text in Geist, the same charts as the
// screen rendered light, and the Ledger logo. Mirrors demo/investor-report.

const _ink = PdfColor.fromInt(0xFF0F1419);
const _ink2 = PdfColor.fromInt(0xFF2B3640);
const _muted = PdfColor.fromInt(0xFF64748B);
const _rule = PdfColor.fromInt(0xFFE2E8F0);
const _wash = PdfColor.fromInt(0xFFF6F8FA);
const _orange = PdfColor.fromInt(0xFFDD742A);
const _good = PdfColor.fromInt(0xFF047857);
const _bad = PdfColor.fromInt(0xFFB91C1C);
const _flag = PdfColor.fromInt(0xFFB45309);
const _flagBg = PdfColor.fromInt(0xFFFEF3C7);

Future<void> downloadReportPdf(BuildContext context, AppState s, Report r) async {
  final name = '${r.subject.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}.pdf';
  try {
    final loc = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (loc == null) return;
    final bytes = await buildReportPdf(s, r);
    await XFile.fromData(bytes, mimeType: 'application/pdf', name: name).saveTo(loc.path);
    if (context.mounted) toast(context, 'Saved $name');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not save the PDF: $e');
  }
}

Future<Uint8List> buildReportPdf(AppState s, Report r) async {
  Future<pw.Font> font(String w) async => pw.Font.ttf(await rootBundle.load('assets/fonts/Geist-$w.ttf'));
  final regular = await font('Regular'), medium = await font('Medium');
  final semi = await font('SemiBold'), bold = await font('Bold');
  final logo = pw.MemoryImage((await rootBundle.load('assets/brand/logo_light.png')).buffer.asUint8List());

  Future<pw.MemoryImage> chart(CustomPainter painter, double w, double h) async =>
      pw.MemoryImage(Uint8List.fromList(await paintToPng(painter, Size(w, h))));

  final d = r.defaultAlive;
  final bridge = r.bridge;
  final weeks = [
    for (final f
        in s.facts
            .where((f) => f.metric == 'demos_week' && f.status == FactStatus.confirmed && f.value != null)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)))
      (shortDate.format(f.date), f.value!),
  ];
  final revenueChart = d == null ? null : await chart(RevenueChartPainter(d, ChartColors.light), 680, 260);
  final cashChart = d == null ? null : await chart(CashChartPainter(d, ChartColors.light), 680, 190);
  final mapChart = d == null ? null : await chart(AliveMapPainter(d, ChartColors.light), 680, 290);
  final bridgeChart = bridge == null || bridge.rows.isEmpty
      ? null
      : await chart(BridgeChartPainter(bridge, ChartColors.light), 680, BridgeChartPainter.heightFor(bridge));
  final demosChart = weeks.length > 1 ? await chart(DemosChartPainter(weeks, ChartColors.light), 360, 170) : null;

  final base = pw.TextStyle(font: regular, fontBold: bold, fontSize: 10, color: _ink, lineSpacing: 2);
  final small = base.copyWith(fontSize: 8.5, color: _muted);
  final section = {for (final sec in r.sections) sec.title: sec};

  pw.Widget heading(String text) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 1.5)),
    ),
    child: pw.Text(
      text.toUpperCase(),
      style: base.copyWith(font: semi, fontSize: 9, letterSpacing: 1.2, color: _ink2),
    ),
  );

  pw.Widget bullets(String title, {bool boxed = false}) {
    final sec = section[title];
    if (sec == null) return pw.SizedBox();
    final kept = keptClaims(sec);
    if (kept.isEmpty) return pw.SizedBox();
    final numbered = title == 'Asks' || title == 'Next month';
    final list = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (i, c) in kept.indexed)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 14, child: pw.Text(numbered ? '${i + 1}.' : '•', style: base)),
                pw.Expanded(child: pw.Text(c.text, style: base)),
              ],
            ),
          ),
      ],
    );
    if (!boxed)
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [heading(sectionHeading(title)), list],
      );
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: pw.BoxDecoration(
        color: title == 'TL;DR' ? _wash : null,
        border: title == 'Asks' ? pw.Border.all(color: _orange, width: 1.4) : null,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(sectionHeading(title), style: base.copyWith(font: semi, fontSize: 11)),
          pw.SizedBox(height: 4),
          list,
        ],
      ),
    );
  }

  pw.Widget table(List<String> header, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths}) => pw.Table(
    columnWidths: widths,
    border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _rule, width: 0.6)),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 1.5)),
        ),
        children: [
          for (final h in header)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(h.toUpperCase(), style: small.copyWith(font: semi, letterSpacing: 0.6)),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            for (final (i, c) in row.indexed)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: pw.Text(c, style: i == 2 && header.length == 4 ? base.copyWith(font: semi) : base),
              ),
          ],
        ),
    ],
  );

  pw.Widget caption(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
    child: pw.Text(
      text,
      style: base.copyWith(font: medium, fontSize: 9.5, color: _ink2),
    ),
  );

  // A chart and its caption always stay on the same page.
  pw.Widget chartBlock(String title, pw.MemoryImage image, {String? legend, double? width}) => pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        caption(title),
        if (legend != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(legend, style: small),
          ),
        pw.Image(image, width: width),
      ],
    ),
  );

  final notCounted = r.allClaims.where((c) => c.flag != ClaimFlag.none).toList();
  final sources = citedFacts(s, r);

  final doc = pw.Document(title: r.subject, author: 'Ledger for Reson8');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by Ledger from facts the founder confirmed. Demo data.', style: small),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: small),
        ],
      ),
      build: (ctx) => [
        pw.Row(
          children: [
            pw.Image(logo, width: 34, height: 34),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RESON8 · INVESTOR UPDATE',
                  style: base.copyWith(font: semi, fontSize: 8.5, color: _orange, letterSpacing: 1.4),
                ),
                pw.Text('October 2026', style: base.copyWith(font: bold, fontSize: 22)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('To Balderton Capital, NP-Hard and angels · From Thomas · Month closed 31 October 2026', style: small),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
          decoration: const pw.BoxDecoration(
            color: _flagBg,
            border: pw.Border(left: pw.BorderSide(color: _flag, width: 3)),
          ),
          child: pw.Text(
            'Demo report. Revenue, burn, cash, customers, deals and meeting notes are invented for a hackathon demo and '
            'are not Reson8\'s real figures. The SDK download counts are real public data.',
            style: small.copyWith(color: const PdfColor.fromInt(0xFF78350F)),
          ),
        ),
        bullets('TL;DR', boxed: true),
        bullets('Asks', boxed: true),
        heading('Key numbers'),
        table(
          const ['Metric', 'September', 'October', 'Change'],
          [
            for (final k in r.kpis) [k.label, k.prev ?? 'n/a', k.curr ?? 'n/a', k.change ?? ''],
          ],
          widths: const {
            0: pw.FlexColumnWidth(2.4),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.2),
          },
        ),
        if (d != null) ...[
          heading('Default alive or default dead?'),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: d.alive ? const PdfColor.fromInt(0xFFECFDF5) : const PdfColor.fromInt(0xFFFEF2F2),
              border: pw.Border.all(color: d.alive ? _good : _bad, width: 1.4),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  d.alive ? 'Default alive' : 'Default dead',
                  style: base.copyWith(font: bold, fontSize: 15, color: d.alive ? _good : _bad),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(defaultAliveVerdict(d), style: base),
                      pw.SizedBox(height: 3),
                      pw.Text(defaultAliveThreshold(d), style: base),
                    ],
                  ),
                ),
              ],
            ),
          ),
          chartBlock(
            'Monthly revenue against monthly expenses, from the September close',
            revenueChart!,
            legend:
                'Blue: revenue (ARR / 12). Orange: expenses (net burn + revenue), held flat. Dark dots: actual closes.',
          ),
          chartBlock('Cash in the bank', cashChart!),
          chartBlock('Dead or alive map: where October puts us, and how far we are from the edge', mapChart!),
          pw.SizedBox(height: 8),
          table(
            const ['Month', 'Revenue / mo', 'Expenses / mo', 'Cash'],
            [
              for (final p in d.projection)
                if (p.month % 3 == 0 || p.month == d.months)
                  [
                    monthLabel(p.month),
                    for (final v in [p.revenue, p.expenses, p.cash]) AppState.formatValue(v, 'EUR'),
                  ],
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'A projection, not a forecast: it assumes October\'s growth holds and costs stay flat. Computed in code from the confirmed facts.',
              style: small,
            ),
          ),
        ],
        if (bridge != null && bridge.rows.isNotEmpty) ...[
          heading('Customers'),
          table(
            const ['Customer', 'Deal', 'ARR'],
            [
              for (final row in bridge.rows)
                [
                  row.lost ? '${row.name} (lost)' : row.name,
                  row.detail,
                  '${row.arr > 0 ? '+' : '−'}${AppState.formatValue(row.arr.abs(), 'EUR')}',
                ],
            ],
            widths: const {0: pw.FlexColumnWidth(2.2), 1: pw.FlexColumnWidth(1.6), 2: pw.FlexColumnWidth(1)},
          ),
          chartBlock('How ARR got from September to October', bridgeChart!),
        ],
        if (notCounted.isNotEmpty) ...[
          heading('Pipeline we are not counting yet'),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: const pw.BoxDecoration(
              color: _flagBg,
              border: pw.Border(left: pw.BorderSide(color: _flag, width: 3)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final c in notCounted) ...[
                  pw.Text(c.text, style: base.copyWith(font: semi)),
                  pw.Text(
                    'Only said, not confirmed in the CRM or a contract. Not included in any number above.',
                    style: small,
                  ),
                  pw.SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
        bullets('Highlights'),
        if (demosChart != null) chartBlock('Demos booked per week', demosChart, width: 260),
        bullets('Lowlights'),
        bullets('Product'),
        bullets('Team'),
        bullets('Next month'),
        pw.SizedBox(height: 14),
        pw.Text('Thanks for your support,\nThomas', style: base),
        heading('Sources'),
        table(
          const ['Source', 'Record', 'Date', 'Fact'],
          [
            for (final f in sources) [_sourceName(f), f.sourceRef, shortDate.format(f.date), f.text],
          ],
          widths: const {
            0: pw.FixedColumnWidth(62),
            1: pw.FixedColumnWidth(110),
            2: pw.FixedColumnWidth(48),
            3: pw.FlexColumnWidth(),
          },
        ),
      ],
    ),
  );
  return doc.save();
}

String _sourceName(Fact f) => switch (f.sourceId) {
  'github' => 'GitHub',
  'jamie' => 'Jamie',
  'hubspot' => 'HubSpot',
  'linkedin' => 'LinkedIn',
  'stripe' => 'Stripe',
  'packages' => 'PyPI · npm',
  'slack' => 'Slack',
  'voice' => 'Voice',
  'founder' => 'Chat',
  _ => f.sourceId,
};
