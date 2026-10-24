import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'agent/claude_client.dart';
import 'agent/runs.dart';
import 'data/connectors.dart';
import 'models/agent_run.dart';
import 'models/fact.dart';
import 'models/feed_item.dart';
import 'models/outbound_message.dart';
import 'models/report.dart';

const slackWebhookUrl = String.fromEnvironment('SLACK_WEBHOOK_URL');

/// The fixed KPI order of the investor update.
const kpiCatalog = <String, String>{
  'arr': 'ARR',
  'customers': 'Paying customers',
  'nrr': 'NRR (trailing 12 months)',
  'demos': 'Demos booked',
  'burn': 'Net burn',
  'cash': 'Cash',
  'runway': 'Runway',
};

class KpiSuggestion {
  KpiSuggestion(this.metric, this.reason, this.factId);
  final String metric;
  final String reason;
  final String? factId;
  bool? accepted;
}

class SimWeek {
  const SimWeek(this.label, this.since, this.until);
  final String label;
  final DateTime since;
  final DateTime until;
}

/// Simulated October 2026. Each "Next week" click advances to the next window.
final simWeeks = [
  SimWeek('Week 1', DateTime(2026, 9, 30, 23, 59), DateTime(2026, 10, 7, 23, 59)),
  SimWeek('Week 2', DateTime(2026, 10, 7, 23, 59), DateTime(2026, 10, 14, 23, 59)),
  SimWeek('Week 3', DateTime(2026, 10, 14, 23, 59), DateTime(2026, 10, 21, 23, 59)),
  SimWeek('Week 4', DateTime(2026, 10, 21, 23, 59), DateTime(2026, 10, 28, 23, 59)),
  SimWeek('Month close', DateTime(2026, 10, 28, 23, 59), DateTime(2026, 10, 31, 23, 59)),
];

class AppState extends ChangeNotifier {
  AppState() {
    agent = Agent(this, ClaudeClient());
    reset();
  }

  late final Agent agent;

  // Simulated time
  int weekIndex = -1;
  DateTime today = DateTime(2026, 10, 1);

  // Data
  final connectors = {for (final id in ['github', 'jamie', 'hubspot', 'linkedin', 'stripe']) id: MockConnector(id)};
  final List<Fact> facts = [];
  final List<FeedItem> feed = [];
  final List<OutboundMessage> outbox = [];
  final List<KpiSuggestion> kpiSuggestions = [];
  Report? report;
  int _factSeq = 0;
  int _msgSeq = 0;

  // Settings
  String cadence = 'Weekly';
  String period = 'Monthly';
  final Set<String> kpis = {'arr', 'customers', 'demos', 'burn', 'cash', 'runway'};
  final Map<String, bool> channels = {'Slack': true, 'WhatsApp': false, 'Email': true};
  bool scripted = !ClaudeClient().hasKey;

  // UI
  int tab = 0;
  String? busy;
  bool get isBusy => busy != null;

  SimWeek? get currentWeek => weekIndex >= 0 ? simWeeks[weekIndex] : null;
  bool get monthClosed => weekIndex >= simWeeks.length - 1;
  bool get canAdvance => !isBusy && !monthClosed;
  String get nextLabel => weekIndex == simWeeks.length - 2 ? 'Close month' : 'Next week';

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void setBusy(String? label) {
    busy = label;
    notifyListeners();
  }

  void touch() => notifyListeners();

  Future<void> reset() async {
    weekIndex = -1;
    today = DateTime(2026, 10, 1);
    facts.clear();
    feed.clear();
    outbox.clear();
    kpiSuggestions.clear();
    report = null;
    _factSeq = 0;
    _msgSeq = 0;
    kpis
      ..clear()
      ..addAll({'arr', 'customers', 'demos', 'burn', 'cash', 'runway'});
    busy = null;
    tab = 0;

    final raw = jsonDecode(await rootBundle.loadString('assets/mock/baseline.json'));
    for (final f in raw['facts'] as List) {
      addFact(
        text: f['text'],
        kind: FactKind.kpi,
        sourceId: f['source'],
        sourceRef: f['ref'],
        owner: 'Lena',
        date: DateTime(2026, 9, 30),
        metric: f['metric'],
        value: (f['value'] as num).toDouble(),
        unit: f['unit'],
        period: '2026-09',
        excerpt: raw['note'],
        status: FactStatus.confirmed,
      );
    }
    feed.add(FeedItem(
      type: FeedType.welcome,
      title: 'Agent is set up for Shelfwise',
      date: today,
      body: 'Hi Lena. I\'m connected to GitHub, Jamie, HubSpot, LinkedIn and Stripe. I\'ll check in every week '
          'and have the October update ready on Oct 31.',
    ));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Ledger

  Fact addFact({
    required String text,
    required FactKind kind,
    required String sourceId,
    required String sourceRef,
    required String owner,
    DateTime? date,
    String? metric,
    double? value,
    String? unit,
    String? period,
    String? excerpt,
    bool statementOnly = false,
    FactStatus status = FactStatus.pending,
  }) {
    final f = Fact(
      id: 'F${++_factSeq}',
      text: text,
      kind: kind,
      sourceId: sourceId,
      sourceRef: sourceRef,
      owner: owner,
      date: date ?? today,
      metric: metric,
      value: value,
      unit: unit,
      period: period,
      excerpt: excerpt,
      statementOnly: statementOnly,
      status: status,
    );
    facts.add(f);
    notifyListeners();
    return f;
  }

  Fact? factById(String id) {
    for (final f in facts) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Fact> get activeFacts => facts.where((f) => f.status != FactStatus.dismissed).toList();

  List<Fact> search(String query) {
    final terms = query.toLowerCase().split(RegExp(r'\W+')).where((t) => t.length > 2).toList();
    if (terms.isEmpty) return activeFacts;
    return activeFacts.where((f) {
      final hay = '${f.text} ${f.metric ?? ''} ${f.sourceRef} ${f.owner}'.toLowerCase();
      return terms.any(hay.contains);
    }).toList();
  }

  void setFactStatus(String id, FactStatus status) {
    factById(id)?.status = status;
    notifyListeners();
  }

  void confirmAll(Iterable<String> ids) {
    for (final id in ids) {
      final f = factById(id);
      if (f != null && f.status == FactStatus.pending) f.status = FactStatus.confirmed;
    }
    notifyListeners();
  }

  void editFact(String id, String text, double? value) {
    final f = factById(id);
    if (f == null) return;
    f.text = text;
    if (value != null) f.value = value;
    f.status = FactStatus.confirmed;
    notifyListeners();
  }

  /// Most recent value of a metric among non-dismissed facts.
  Fact? latestMetric(String metric, {String? period, bool confirmedOnly = false}) {
    final candidates = facts.where((f) =>
        f.metric == metric &&
        f.status != FactStatus.dismissed &&
        (!confirmedOnly || f.status == FactStatus.confirmed) &&
        (period == null || f.period == period));
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  /// Where a fact's raw record lives (for the source popover).
  Future<SourceItem?> sourceItemFor(Fact f) async => connectors[f.sourceId]?.byId(f.sourceRef);

  // ---------------------------------------------------------------------------
  // KPI suggestions

  void addKpiSuggestion(String metric, String reason, String? factId) {
    if (kpis.contains(metric) || kpiSuggestions.any((k) => k.metric == metric)) return;
    kpiSuggestions.add(KpiSuggestion(metric, reason, factId));
    notifyListeners();
  }

  void resolveKpiSuggestion(KpiSuggestion s, bool accept) {
    s.accepted = accept;
    if (accept) kpis.add(s.metric);
    if (s.factId != null) setFactStatus(s.factId!, FactStatus.confirmed);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Outbox

  OutboundMessage draftMessage(String to, String channel, String text, String? reason) {
    final m = OutboundMessage(
      id: 'M${++_msgSeq}',
      to: to,
      channel: channel,
      text: text,
      createdAt: today,
      reason: reason,
    );
    outbox.add(m);
    notifyListeners();
    return m;
  }

  OutboundMessage? messageById(String id) {
    for (final m in outbox) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> approveMessage(String id, {String? editedText}) async {
    final m = messageById(id);
    if (m == null) return;
    if (editedText != null) m.text = editedText;
    m.status = MessageStatus.sent;
    m.sentAt = today;
    notifyListeners();
    if (slackWebhookUrl.isNotEmpty && m.channel.toLowerCase() == 'slack') {
      try {
        await http.post(Uri.parse(slackWebhookUrl),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'text': '*To ${m.to}* (sent by Shelfwise update agent on behalf of Lena)\n${m.text}'}));
      } catch (_) {
        // Demo keeps working without the real webhook.
      }
    }
  }

  void rejectMessage(String id) {
    messageById(id)?.status = MessageStatus.rejected;
    notifyListeners();
  }

  Future<void> simulateReply(String id) async {
    final m = messageById(id);
    if (m == null || m.status != MessageStatus.sent) return;
    final replies = jsonDecode(await rootBundle.loadString('assets/mock/slack_replies.json')) as Map<String, dynamic>;
    m.reply = replies[m.to] as String? ?? 'Thanks, will check!';
    m.status = MessageStatus.replied;
    notifyListeners();
    await agent.inbound(m.reply!, sourceId: m.channel.toLowerCase(), from: m.to, replyTo: m);
  }

  // ---------------------------------------------------------------------------
  // Simulated time + runs

  Future<void> advance() async {
    if (!canAdvance) return;
    weekIndex++;
    final w = simWeeks[weekIndex];
    today = DateTime(w.until.year, w.until.month, w.until.day);
    notifyListeners();
    await agent.checkIn(w, isClose: monthClosed);
    final drop = demoDrop();
    if (drop != null && !monthClosed) await agent.anomaly(w, drop);
  }

  /// Deterministic anomaly trigger: this week's demos fell by more than 50%.
  (Fact, Fact)? demoDrop() {
    final w = currentWeek;
    if (w == null) return null;
    final weekly = facts.where((f) => f.metric == 'demos_week' && f.status != FactStatus.dismissed).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (weekly.length < 2) return null;
    final curr = weekly.last;
    final prev = weekly[weekly.length - 2];
    if (!curr.date.isAfter(w.since)) return null;
    if (curr.value != null && prev.value != null && curr.value! < prev.value! * 0.5) return (prev, curr);
    return null;
  }

  Future<void> sendInbound(String text, {String sourceId = 'founder', String? docName}) =>
      agent.inbound(text, sourceId: sourceId, from: 'Lena', docName: docName);

  Future<void> sendDocument(String name, Uint8List bytes, String mime) => agent.document(name, bytes, mime);

  Future<void> draftReport() async {
    await agent.report();
    tab = 4;
    notifyListeners();
  }

  void approveReport() {
    report?.approved = true;
    feed.insert(
        0,
        FeedItem(
          type: FeedType.info,
          title: 'October update approved',
          date: today,
          body: 'Queued for Northstar Ventures and 5 angels (simulated). Next check-in: Nov 7.',
        ));
    notifyListeners();
  }

  void addFeed(FeedItem item) {
    feed.insert(0, item);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Formatting

  static String formatValue(double? v, String? unit) {
    if (v == null) return '–';
    switch (unit) {
      case 'EUR':
        final a = v.abs();
        final sign = v < 0 ? '−' : '';
        if (a >= 1000000) return '$sign€${(a / 1000000).toStringAsFixed(2)}M';
        if (a >= 1000) return '$sign€${(a / 1000).round()}k';
        return '$sign€${a.round()}';
      case '%':
        return '${v.round()}%';
      case 'months':
        return '${v.round()} months';
      default:
        return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    }
  }

  List<KpiRow> buildKpiRows() {
    final rows = <KpiRow>[];
    for (final entry in kpiCatalog.entries) {
      if (!kpis.contains(entry.key)) continue;
      final prev = latestMetric(entry.key, period: '2026-09', confirmedOnly: true);
      final curr = latestMetric(entry.key, period: '2026-10', confirmedOnly: true);
      String? change;
      if (prev?.value != null && curr?.value != null) {
        final p = prev!.value!, c = curr!.value!;
        switch (entry.key) {
          case 'customers':
            change = '${c - p >= 0 ? '+' : ''}${(c - p).round()}';
          case 'nrr':
            change = '${c - p >= 0 ? '+' : ''}${(c - p).round()} pts';
          case 'runway':
            change = '${c - p >= 0 ? '+' : ''}${(c - p).round()} months';
          case 'cash':
            change = null;
          default:
            final pct = (c - p) / p * 100;
            change = '${pct >= 0 ? '+' : ''}${pct.abs() >= 10 ? pct.round() : pct.toStringAsFixed(1)}%';
        }
      }
      rows.add(KpiRow(
        label: entry.value,
        prev: prev == null ? null : formatValue(prev.value, prev.unit),
        curr: curr == null ? null : formatValue(curr.value, curr.unit),
        change: change,
        prevFactId: prev?.id,
        currFactId: curr?.id,
      ));
    }
    return rows;
  }

  void recordError(AgentRun run, Object e) {
    run.error = e.toString();
    debugPrint('Agent error: $e');
  }
}
