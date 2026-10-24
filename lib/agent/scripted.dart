import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/agent_run.dart';
import '../models/fact.dart';
import '../models/report.dart';
import 'tools.dart';

// Deterministic versions of the four runs. They call the same tools as the
// live agent, so the ledger, feed and trace look the same; only the
// decisions come from the mock data instead of the model.

final _day = DateFormat('yyyy-MM-dd');

Future<Object?> _t(AppState s, ToolHost h, String name, Map<String, dynamic> input) async {
  final step = RunStep(type: StepType.tool, name: name, input: input);
  h.run.steps.add(step);
  s.touch();
  await Future.delayed(const Duration(milliseconds: 220));
  final out = await h.call(name, input);
  step.output = out;
  step.ms = 220;
  s.touch();
  return out;
}

void _think(AppState s, ToolHost h, String note) {
  h.run.steps.add(RunStep(type: StepType.model, name: 'scripted', input: note, output: 'planned next tool calls'));
  s.touch();
}

const _questions = [
  ['Anything from the team this week the tools can\'t see, like hires, departures or big customer conversations?'],
  ['FreshMart Nord is our first chain customer. Should it lead the October update?'],
  ['Demo bookings fell from 44 to 12. I\'m checking with Anna. Do you already know what happened?'],
  ['FreshMart said they want 40 stores in Q1. Is there anything in writing yet?'],
  ['October numbers are in. Confirm them and I\'ll draft the investor update.'],
];

const _summaries = [
  'Good first week: 2 new stores (+€24k ARR), supplier order export shipped, and 31 demos from the new LinkedIn campaign. '
      'Mara from Northstar asked for NRR in the next update, so I suggest adding it to the KPIs.',
  'Big week: Release 2.0 brings fresh produce forecasting, and FreshMart Nord signed a paid pilot for 12 stores (+€36k ARR). '
      'The LinkedIn case study drove a record 44 demos.',
  'Mixed week: forecast latency is down 60%, but one store closed (−€9k ARR) and demo bookings dropped to 12 with no LinkedIn activity.',
  'Release 2.1 shipped, 1 new store (+€7k ARR) and demos recovered to 38. FreshMart wants 40 stores in Q1, but that was only said in the pilot review.',
  'October closed at €668k ARR (+9.5%) and 51 customers. Net burn rose to €171k, runway is now 16 months.',
];

Future<void> scriptedCheckIn(AppState s, ToolHost h, SimWeek w, DateTime since, bool isClose) async {
  final idx = simWeeks.indexOf(w);
  _think(s, h, 'Read all sources for ${w.label}');
  await _t(s, h, 'list_sources', {});
  final records = <Map<String, dynamic>>[];
  for (final id in s.connectors.keys) {
    await _t(s, h, 'fetch_source', {'source': id, 'since': _day.format(since), 'until': _day.format(w.until)});
    final items = await s.connectors[id]!.fetch(w.since, w.until);
    for (final i in items) {
      for (final f in i.hintedFacts) {
        records.add({...f, 'source': id, 'source_ref': i.id});
      }
    }
  }
  _think(s, h, 'Dedupe against the ledger');
  await _t(s, h, 'ledger_search', {'query': isClose ? 'kpi september' : 'october ${w.label.toLowerCase()}'});
  _think(s, h, 'Propose ${records.length} facts');
  for (final r in records) {
    final out = await _t(s, h, 'ledger_propose', {
      'text': r['text'],
      'kind': r['kind'],
      'source': r['source'],
      'source_ref': r['source_ref'],
      'owner': r['owner'],
      if (r['metric'] != null) 'metric': r['metric'],
      if (r['value'] != null) 'value': r['value'],
      if (r['unit'] != null) 'unit': r['unit'],
      if (r['period'] != null) 'period': r['period'],
      if (r['statement_only'] == true) 'statement_only': true,
    }) as Map<String, dynamic>;
    if (r['suggest_kpi'] != null) {
      await _t(s, h, 'suggest_kpi', {
        'metric': r['suggest_kpi'],
        'reason': 'Lead investor (Mara, Northstar Ventures) asked for NRR in the next update (Jamie, Oct 3).',
        'fact_id': out['id'],
      });
    }
  }
  await _t(s, h, 'ask_founder', {'questions': _questions[idx]});
  h.run.summary = _summaries[idx];
}

Future<void> scriptedAnomaly(AppState s, ToolHost h, SimWeek w, DateTime since, Fact prev, Fact curr) async {
  _think(s, h, 'Demos fell ${prev.value!.round()} → ${curr.value!.round()}. Look for the cause.');
  final range = {'since': _day.format(since), 'until': _day.format(w.until)};
  await _t(s, h, 'fetch_source', {'source': 'linkedin', ...range});
  await _t(s, h, 'fetch_source', {'source': 'hubspot', ...range});
  await _t(s, h, 'ledger_search', {'query': 'demos linkedin campaign'});
  _think(s, h, 'No posts and no ad delivery since Oct 14. Find the owner.');
  await _t(s, h, 'team_directory', {});
  await _t(s, h, 'message_teammate', {
    'person': 'Anna',
    'channel': 'Slack',
    'text': 'Hi Anna, quick one for the October investor update: demo bookings dropped from ${prev.value!.round()} last week '
        'to ${curr.value!.round()} this week, and LinkedIn shows no posts and no ad delivery since Oct 14. '
        'Do you know what happened, and is it fixed? Thanks! (sent by Lena\'s update agent)',
    'reason': 'Anna owns LinkedIn and demo bookings. The sources show the drop but not why.',
  });
  h.run.summary = 'Demos fell from ${prev.value!.round()} to ${curr.value!.round()}; LinkedIn had no posts and the ads stopped '
      'delivering on Oct 14. Anna owns this, so I drafted a Slack message for you to approve.';
}

Future<void> scriptedInbound(AppState s, ToolHost h, String text,
    {required String sourceId, required String from, required String ref}) async {
  final t = text.toLowerCase();
  _think(s, h, 'Extract facts from $from');
  await _t(s, h, 'ledger_search', {'query': t.contains('linkedin') ? 'demos linkedin' : 'team burn'});
  final proposals = <Map<String, dynamic>>[];
  if (t.contains('suspend') || t.contains('expired')) {
    proposals.addAll([
      {
        'text': 'LinkedIn ad account was suspended on Oct 14 over an expired company card; fixed, ads running again, backup payment method added',
        'kind': 'lowlight',
      },
      {'text': 'LinkedIn posts paused for two days (Anna out sick), back on schedule', 'kind': 'context'},
    ]);
  } else if (t.contains('engineer')) {
    proposals.add({'text': 'Two backend engineers started this month', 'kind': 'team'});
    final m = RegExp(r'(\d{3})\s?k').firstMatch(t);
    if (m != null) {
      proposals.add({
        'text': 'Lena estimates October net burn at about €${m.group(1)}k after the two hires',
        'kind': 'context',
        'metric': 'burn_estimate',
        'value': double.parse(m.group(1)!) * 1000,
        'unit': 'EUR',
        'statement_only': true,
      });
    }
  } else {
    proposals.add({'text': text.length > 160 ? '${text.substring(0, 157)}…' : text, 'kind': 'context'});
  }
  for (final p in proposals) {
    await _t(s, h, 'ledger_propose', {...p, 'source': sourceId, 'source_ref': ref, 'owner': from});
  }
  h.run.summary = proposals.length == 1
      ? 'Added 1 fact for you to confirm.'
      : 'Added ${proposals.length} facts for you to confirm.';
}

Future<Report> scriptedReport(AppState s, ToolHost h, List<KpiRow> kpis) async {
  _think(s, h, 'Draft the October update from confirmed facts');
  await _t(s, h, 'ledger_search', {'query': 'october highlight lowlight product team'});

  bool ok(Fact f) => f.status == FactStatus.confirmed;
  List<String> refs(List<String> rs) => [for (final f in s.facts) if (ok(f) && rs.contains(f.sourceRef)) f.id];
  List<String> metric(String m, [String period = '2026-10']) => [
        for (final f in s.facts) if (ok(f) && f.metric == m && f.period == period) f.id,
      ];
  List<String> where(bool Function(Fact) p) => [for (final f in s.facts) if (ok(f) && p(f)) f.id];
  final hires = where((f) => f.kind == FactKind.team && (f.sourceId == 'founder' || f.sourceId == 'voice'));
  final slack = where((f) => f.sourceId == 'slack' && f.kind == FactKind.lowlight);

  Claim c(String text, List<String> ids) => Claim(text: text, factIds: ids.toSet().toList());

  final sub = Report(
    period: 'October 2026',
    subject: 'Shelfwise – October 2026 update',
    kpis: kpis,
    sections: [
      ReportSection('TL;DR', [
        c('ARR up 9.5% to €668k, driven by our first chain pilot (FreshMart Nord, 12 stores).',
            [...metric('arr'), ...metric('arr', '2026-09'), ...refs(['hs-deal-2310'])]),
        c('Release 2.0 brings forecasting to fresh produce, our most requested feature.', refs(['gh-rel-2.0'])),
        c('Net burn rose to €171k after two hires; runway is now 16 months.',
            [...metric('burn'), ...metric('runway'), ...hires]),
      ]),
      ReportSection('Highlights', [
        c('Paid pilot with FreshMart Nord: 12 stores, +€36k ARR. They want to roll out to 40 stores in Q1.',
            refs(['hs-deal-2310', 'jamie-mtg-1027'])),
        c('Release 2.0: fresh produce forecasting is live for all customers.', refs(['gh-rel-2.0'])),
        c('Our case study on LinkedIn reached 52k impressions and drove a record 44 demos in one week.', refs(['li-wk41'])),
      ]),
      ReportSection('Lowlights', [
        c('Demo bookings fell to 12 in week 3: our LinkedIn ad account was suspended over an expired card. '
            'Fixed, and we added a backup payment method.', [...refs(['li-wk42']), ...slack]),
        c('One store closed for reasons unrelated to us (−€9k ARR).', refs(['hs-churn-0457'])),
        c('Net burn is up 20% after two engineering hires; runway is 16 months.',
            [...metric('burn'), ...metric('burn', '2026-09'), ...metric('runway'), ...hires]),
      ]),
      ReportSection('Product', [
        c('Releases 2.0 and 2.1, supplier order export, forecast latency down 60%.',
            refs(['gh-rel-2.0', 'gh-rel-2.1', 'gh-pr-412', 'gh-pr-447'])),
      ]),
      ReportSection('Team', [
        c('Two engineers joined; we are interviewing for a senior ML engineer.', [...hires, ...refs(['jamie-mtg-1016'])]),
      ]),
      ReportSection('Asks', [
        c('Intros to category managers at regional grocery chains.', refs(['hs-deal-2310'])),
        c('Referrals for a senior ML engineer with forecasting experience.', refs(['jamie-mtg-1016'])),
      ]),
    ],
  );
  await _t(s, h, 'submit_report', {
    'subject': sub.subject,
    for (final sec in sub.sections)
      sec.title.toLowerCase().replaceAll(';', '').replaceAll(' ', '_'): [
        for (final cl in sec.claims) {'text': cl.text, 'fact_ids': cl.factIds},
      ],
  });
  return sub;
}

Future<void> scriptedVerify(AppState s, ToolHost h, Report r) async {
  _think(s, h, 'Separate verifier: check every claim against the ledger');
  final claims = r.allClaims.toList();
  await _t(s, h, 'verify_claims', {
    'results': [
      for (var i = 0; i < claims.length; i++)
        {
          'claim_id': 'C${i + 1}',
          'status': switch (claims[i].flag) {
            ClaimFlag.none => 'supported',
            ClaimFlag.weak => 'weak',
            ClaimFlag.unsupported => 'unsupported',
          },
          'reason': claims[i].flagReason ?? 'Backed by cited facts.',
        },
    ],
  });
}
