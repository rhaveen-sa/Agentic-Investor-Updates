import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
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
  'customers': 'Paying teams',
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
  /// The simulated week we are in (0-3 = Oct weeks, 4 = month close).
  int weekIndex = 0;
  DateTime today = DateTime(2026, 10, 7);

  /// Weeks whose check-in has run.
  final Set<int> ranWeeks = {};

  /// The week whose conversation the Agent screen shows.
  int viewWeek = 0;

  // Data
  final connectors = {for (final id in ['github', 'jamie', 'hubspot', 'linkedin', 'stripe', 'packages']) id: MockConnector(id)};
  final List<Fact> facts = [];
  final List<FeedItem> feed = [];
  final List<OutboundMessage> outbox = [];
  final List<KpiSuggestion> kpiSuggestions = [];
  Report? report;
  int _factSeq = 0;
  int _msgSeq = 0;

  // Settings
  ThemeMode themeMode = ThemeMode.light;
  String cadence = 'Week';
  String period = 'Monthly';
  final Set<String> kpis = {'arr', 'customers', 'demos', 'burn', 'cash', 'runway'};
  final Map<String, bool> channels = {'Slack': true, 'WhatsApp': false, 'Email': true};
  bool scripted = !ClaudeClient().hasKey;

  // UI
  int tab = 0;
  String? busy;
  bool get isBusy => busy != null;

  SimWeek? get currentWeek => simWeeks[weekIndex];
  bool get monthClosed => weekIndex >= simWeeks.length - 1;

  /// The last of the four October weeks we have reached.
  int get lastWeek => weekIndex.clamp(0, 3);
  bool get currentWeekRan => ranWeeks.contains(weekIndex);
  bool get canRunCheckIn => !isBusy && !ranWeeks.contains(viewWeek);
  bool get canCloseMonth => !isBusy && !monthClosed && viewWeek == 3 && ranWeeks.contains(3);

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
    weekIndex = 0;
    today = DateTime(2026, 10, 7);
    ranWeeks.clear();
    viewWeek = 0;
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
        owner: 'Thomas',
        date: DateTime(2026, 9, 30),
        metric: f['metric'],
        value: (f['value'] as num).toDouble(),
        unit: f['unit'],
        period: '2026-09',
        excerpt: raw['note'],
        status: FactStatus.confirmed,
      );
    }
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
            body: jsonEncode({'text': '*To ${m.to}* (sent by Reson8 update agent on behalf of Thomas)\n${m.text}'}));
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

  /// Week selector: any October week can be opened. Opening a later week
  /// moves the simulated date there; check-ins are started separately.
  void selectWeek(int i) {
    viewWeek = i;
    if (i > weekIndex) {
      weekIndex = i;
      final w = simWeeks[i];
      today = DateTime(w.until.year, w.until.month, w.until.day);
    }
    notifyListeners();
  }

  /// Runs the check-in of the week being viewed.
  Future<void> runCheckIn() async {
    if (!canRunCheckIn) return;
    final week = viewWeek;
    ranWeeks.add(week);
    final w = simWeeks[week];
    await agent.checkIn(w, isClose: false);
    final drop = await demoDrop(week);
    if (drop != null) await agent.anomaly(w, drop.prev, drop.curr);
  }

  Future<void> closeMonth() async {
    if (!canCloseMonth) return;
    weekIndex = 4;
    viewWeek = 3;
    ranWeeks.add(4);
    today = DateTime(2026, 10, 31);
    notifyListeners();
    await agent.checkIn(simWeeks[4], isClose: true);
  }

  /// Runs the next step of the month: this week's check-in, else the next
  /// week's, else the month close.
  Future<void> advance() async {
    if (canRunCheckIn) return runCheckIn();
    if (canCloseMonth) return closeMonth();
    if (viewWeek < 3) {
      selectWeek(viewWeek + 1);
      return runCheckIn();
    }
  }

  /// Deterministic anomaly trigger: demo bookings in [week] fell by more
  /// than 50% versus the week before. Read from the growth source, so it
  /// works in whatever order the weeks are run.
  Future<({int prev, int curr})?> demoDrop(int week) async {
    if (week == 0) return null;
    Future<int?> demos(SimWeek w) async {
      final items = await connectors['linkedin']!.fetch(w.since, w.until);
      for (final i in items) {
        final d = (i.json['data'] as Map?)?['demos'];
        if (d is num) return d.toInt();
      }
      return null;
    }

    final prev = await demos(simWeeks[week - 1]);
    final curr = await demos(simWeeks[week]);
    if (prev == null || curr == null || curr >= prev * 0.5) return null;
    return (prev: prev, curr: curr);
  }

  Future<void> sendInbound(String text, {String sourceId = 'founder', String? docName}) {
    return agent.inbound(text, sourceId: sourceId, from: 'Thomas', docName: docName);
  }

  Future<void> sendDocument(String name, Uint8List bytes, String mime) => agent.document(name, bytes, mime);

  Future<void> draftReport() async {
    await agent.report();
    tab = 3;
    notifyListeners();
  }

  /// Teammate messages still waiting: not yet approved, or sent without a reply.
  List<OutboundMessage> get waitingMessages =>
      outbox.where((m) => m.status == MessageStatus.draft || m.status == MessageStatus.sent).toList();

  /// Pending facts or waiting teammate messages that should be answered before drafting the report.
  bool get hasOpenQuestions => facts.any((f) => f.status == FactStatus.pending) || waitingMessages.isNotEmpty;

  /// The report button next to the week stepper: opens the report if there is one, else goes to the
  /// open questions, else closes the month (if needed), confirms the close run's facts and drafts.
  Future<void> openOrCreateReport() async {
    if (isBusy) return;
    if (report != null) return setTab(3);
    if (facts.any((f) => f.status == FactStatus.pending)) return setTab(1);
    final waiting = waitingMessages;
    if (waiting.isNotEmpty) {
      final id = waiting.first.id;
      for (final item in feed) {
        if (item.run?.messageIds.contains(id) ?? false) {
          selectWeek(item.week);
          break;
        }
      }
      return setTab(0);
    }
    if (!monthClosed) {
      if (viewWeek != 3) selectWeek(3);
      if (!canCloseMonth) return;
      await closeMonth();
    }
    // The close run proposes October's KPIs as pending facts; accept them so the report can use them.
    for (final item in feed) {
      if (item.offersReport && item.run != null) {
        confirmAll(item.run!.proposedFactIds);
        break;
      }
    }
    await draftReport();
  }

  void approveReport() {
    report?.approved = true;
    addFeed(FeedItem(
          type: FeedType.info,
          title: 'October update approved',
          date: today,
          body: 'Queued for Balderton Capital, NP-Hard and angels (simulated). Next check-in: Nov 7.',
        ));
  }

  void addFeed(FeedItem item) {
    item.week = viewWeek;
    feed.insert(0, item);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Formatting

  static String formatValue(double? v, String? unit) {
    if (v == null) return 'n/a';
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

  /// Default alive or default dead (Paul Graham): if expenses stay flat and
  /// revenue keeps growing at this month's rate, does revenue catch up with
  /// expenses before the cash runs out? Null until ARR for both months, net
  /// burn and cash are all confirmed.
  DefaultAlive? buildDefaultAlive() {
    final arrPrev = latestMetric('arr', period: '2026-09', confirmedOnly: true);
    final arr = latestMetric('arr', period: '2026-10', confirmedOnly: true);
    final burn = latestMetric('burn', period: '2026-10', confirmedOnly: true);
    final cash = latestMetric('cash', period: '2026-10', confirmedOnly: true);
    final a0 = arrPrev?.value, a1 = arr?.value, b = burn?.value, c0 = cash?.value;
    if (a0 == null || a1 == null || b == null || c0 == null || a0 <= 0) return null;

    final revenue = a1 / 12;
    final growth = a1 / a0 - 1;

    // Month by month: pay the gap from cash, then grow revenue. 120 months
    // without break-even counts as dead. Same model as demo/investor-report/build.py.
    (bool, int, double) simulate(double g, {double? atBurn}) {
      final expenses = (atBurn ?? b) + revenue; // net burn = expenses - revenue
      var r = revenue, c = c0;
      for (var m = 0; m < 120; m++) {
        if (r >= expenses) return (true, m, c);
        c -= expenses - r;
        if (c <= 0) return (false, m + 1, 0);
        r *= 1 + g;
      }
      return (false, 120, c);
    }

    // Lowest steady monthly growth that still breaks even, by bisection.
    double minGrowth(double atBurn) {
      var lo = 0.0, hi = 1.0;
      for (var i = 0; i < 40; i++) {
        final mid = (lo + hi) / 2;
        if (simulate(mid, atBurn: atBurn).$1) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      return hi;
    }

    // Highest net burn that still breaks even at this month's growth.
    var lo = b, hi = 2000000.0;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (simulate(growth, atBurn: mid).$1) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final expenses = b + revenue;
    final projection = <ProjectionPoint>[];
    var r = revenue, c = c0;
    for (var m = 0; m < 16; m++) {
      projection.add(ProjectionPoint(m, r, expenses, c));
      c += r - expenses;
      r *= 1 + growth;
    }

    // September actuals, so the charts start there.
    final sepBurn = latestMetric('burn', period: '2026-09', confirmedOnly: true)?.value;
    final sepCash = latestMetric('cash', period: '2026-09', confirmedOnly: true)?.value;
    final history = [
      if (sepBurn != null && sepCash != null) ProjectionPoint(-1, a0 / 12, sepBurn + a0 / 12, sepCash),
    ];

    final (alive, months, cashLeft) = simulate(growth);
    return DefaultAlive(
      alive: alive,
      monthlyGrowth: growth,
      months: months,
      cashLeft: cashLeft,
      minGrowth: minGrowth(b),
      factIds: [arrPrev!.id, arr!.id, burn!.id, cash!.id],
      burn: b,
      cash: c0,
      maxBurn: lo,
      projection: projection,
      edge: [
        for (var i = 0; i <= 40; i++)
          (burn: 150000 + 200000 * i / 40, growth: minGrowth(150000 + 200000 * i / 40)),
      ],
      history: history,
    );
  }

  /// New and lost customers from confirmed new_arr / churned_arr facts, and
  /// the bridge from September to October ARR. Filters on metric, not kind:
  /// some deals are logged as context.
  ArrBridge? buildArrBridge() {
    final start = latestMetric('arr', period: '2026-09', confirmedOnly: true);
    final end = latestMetric('arr', period: '2026-10', confirmedOnly: true);
    if (start?.value == null || end?.value == null) return null;
    final rows = <CustomerRow>[];
    for (final f in facts) {
      if (f.status != FactStatus.confirmed || f.value == null) continue;
      if (f.metric != 'new_arr' && f.metric != 'churned_arr') continue;
      // The CRM record title names the customers, e.g. "Closed won: Brugman Verzekeringen".
      final title = f.excerpt?.split('\n').first ?? f.text;
      var name = title.contains(': ') ? title.split(': ').sublist(1).join(': ') : title;
      var detail = '';
      final paren = RegExp(r'^(.*?)\s*(?:paid pilot)?\s*\((.*)\)$').firstMatch(name);
      if (paren != null) {
        name = paren.group(1)!.trim();
        detail = 'Paid pilot, ${paren.group(2)}';
      } else if (name.endsWith(' paid pilot')) {
        name = name.substring(0, name.length - ' paid pilot'.length);
        detail = 'Paid pilot';
      }
      if (detail.isEmpty) detail = name.contains(', ') ? 'New paying teams' : 'New paying team';
      if (f.metric == 'churned_arr') detail = 'Lost';
      rows.add(CustomerRow(name: name, detail: detail, arr: f.value!, factId: f.id));
    }
    rows.sort((a, b) => b.arr.compareTo(a.arr));
    return ArrBridge(start: start!.value!, end: end!.value!, rows: rows, startFactId: start.id, endFactId: end.id);
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
            change = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
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
