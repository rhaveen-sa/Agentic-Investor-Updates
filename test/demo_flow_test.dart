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
    await s.sendInbound('Two backend engineers started this week, that takes net burn to about 171k.', sourceId: 'voice');
    s.confirmAll(s.facts.map((f) => f.id));

    await s.advance(); // week 2
    s.confirmAll(s.facts.map((f) => f.id));

    await s.advance(); // week 3: demo drop -> Slack draft to Anna
    final msg = s.outbox.single;
    expect(msg.to, 'Anna');
    await s.approveMessage(msg.id);
    await s.simulateReply(msg.id);
    expect(msg.status, MessageStatus.replied);
    expect(s.facts.any((f) => f.sourceId == 'slack' && f.kind == FactKind.lowlight), isTrue);
    s.confirmAll(s.facts.map((f) => f.id));

    await s.advance(); // week 4
    s.confirmAll(s.facts.map((f) => f.id));

    expect(s.nextLabel, 'Close month');
    await s.advance(); // close
    expect(s.monthClosed, isTrue);
    s.confirmAll(s.facts.map((f) => f.id));
    await s.draftReport();

    final r = s.report!;
    final text = reportAsText(r);
    // ignore: avoid_print
    print(text);
    expect(text, contains('€668k'));
    expect(text, contains('NRR'));
    expect(r.kpis.firstWhere((k) => k.label == 'ARR').change, '+9.5%');
    final flagged = r.allClaims.where((c) => c.flag != ClaimFlag.none).toList();
    // ignore: avoid_print
    print('FLAGGED: ${flagged.map((c) => '${c.text} -> ${c.flagReason}').join('\n')}');
    expect(flagged.length, 1);
    expect(flagged.single.text, contains('40 stores'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
