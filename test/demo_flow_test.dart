import 'package:agentic_investor_ai/app_state.dart';
import 'package:agentic_investor_ai/models/fact.dart';
import 'package:agentic_investor_ai/models/outbound_message.dart';
import 'package:agentic_investor_ai/models/report.dart';
import 'package:agentic_investor_ai/ui/report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scripted demo runs end to end', () async {
    final s = AppState();
    await s.reset();
    s.scripted = true;

    // Week 1: check-in, NRR suggestion, founder adds hires by chat.
    await s.advance();
    expect(s.kpiSuggestions.single.metric, 'nrr');
    s.resolveKpiSuggestion(s.kpiSuggestions.single, true);
    s.confirmAll(s.facts.map((f) => f.id));
    await s.sendInbound('Two engineers started this week, that takes net burn to about 231k.', sourceId: 'voice');
    s.confirmAll(s.facts.map((f) => f.id));

    await s.advance(); // week 2
    s.confirmAll(s.facts.map((f) => f.id));

    await s.advance(); // week 3: demo drop -> Slack draft to Mirte
    final msg = s.outbox.single;
    expect(msg.to, 'Mirte');
    await s.approveMessage(msg.id);
    await s.simulateReply(msg.id);
    expect(msg.status, MessageStatus.replied);
    expect(s.facts.any((f) => f.sourceId == 'slack' && f.kind == FactKind.lowlight), isTrue);
    s.confirmAll(s.facts.map((f) => f.id));

    await s.advance(); // week 4
    s.confirmAll(s.facts.map((f) => f.id));

    expect(s.canCloseMonth, isTrue);
    await s.advance(); // close
    expect(s.monthClosed, isTrue);
    s.confirmAll(s.facts.map((f) => f.id));
    await s.draftReport();

    final r = s.report!;
    final text = reportAsText(r);
    // ignore: avoid_print
    print(text);
    expect(text, contains('€413k'));
    expect(text, contains('30.7k'));
    expect(text, contains('NRR'));
    expect(r.kpis.firstWhere((k) => k.label == 'ARR').change, '+17.3%');
    expect(r.kpis.firstWhere((k) => k.label == 'Paying teams').curr, '44');
    expect(r.kpis.firstWhere((k) => k.label == 'Runway').curr, '17 months');
    final flagged = r.allClaims.where((c) => c.flag != ClaimFlag.none).toList();
    // ignore: avoid_print
    print('FLAGGED: ${flagged.map((c) => '${c.text} -> ${c.flagReason}').join('\n')}');
    expect(flagged.length, 1);
    expect(flagged.single.text, contains('14 clinics'));

    // Default alive at October's growth: break-even in 13 months with €1.83M left,
    // and the answer flips below about 8.6% a month.
    final d = r.defaultAlive!;
    expect(d.alive, isTrue);
    expect(d.months, 13);
    expect(d.cashLeft, closeTo(1826889, 1));
    expect(d.minGrowth, closeTo(0.0859, 0.0005));
    expect(text, contains('Default alive.'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('weeks can be opened and run in any order', () async {
    final s = AppState();
    await s.reset();
    s.scripted = true;

    s.selectWeek(2); // jump straight to week 3
    expect(s.today, DateTime(2026, 10, 21));
    expect(s.feed, isEmpty, reason: 'opening a week must not start its check-in');
    await s.runCheckIn();
    expect(s.outbox.single.to, 'Mirte', reason: 'the demo drop is detected without weeks 1 and 2');

    s.selectWeek(0); // go back and run week 1 afterwards
    await s.runCheckIn();
    expect(s.ranWeeks, {0, 2});
    expect(s.feed.where((f) => f.week == 0), isNotEmpty);
  });
}
