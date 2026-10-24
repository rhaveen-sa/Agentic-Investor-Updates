import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/agent_run.dart';
import '../models/fact.dart';
import '../models/feed_item.dart';
import '../models/outbound_message.dart';
import '../models/report.dart';
import 'claude_client.dart';
import 'prompts.dart';
import 'scripted.dart';
import 'tools.dart';

final _day = DateFormat('yyyy-MM-dd');
final _short = DateFormat('MMM d');

/// The four agent runs. Each runs live against Claude, or scripted (same
/// tools, deterministic inputs) when there is no key, scripted mode is on, or
/// the live run fails.
class Agent {
  Agent(this.s, this.claude);

  final AppState s;
  final ClaudeClient claude;

  bool get live => !s.scripted && claude.hasKey;

  Future<ToolHost> _go(
    AgentRun run,
    String busyLabel,
    Future<void> Function(ToolHost h) liveRun,
    Future<void> Function(ToolHost h) scriptedRun,
  ) async {
    s.setBusy(busyLabel);
    final host = ToolHost(s, run);
    try {
      if (live) {
        await liveRun(host);
      } else {
        run.scripted = true;
        await scriptedRun(host);
      }
    } catch (e) {
      s.recordError(run, e);
      run.scripted = true;
      run.steps.add(RunStep(
        type: StepType.model,
        name: 'fallback',
        input: 'Live agent failed: $e',
        output: 'Continuing with the scripted run',
      ));
      s.touch();
      try {
        await scriptedRun(host);
      } catch (e2) {
        debugPrint('Scripted run failed too: $e2');
      }
    } finally {
      run.done = true;
      s.setBusy(null);
    }
    return host;
  }

  Future<String> _loop(AgentRun run, ToolHost h, List<Map<String, dynamic>> tools, List<Object> content) =>
      claude.runLoop(
        run: run,
        system: systemPrompt,
        tools: tools,
        userContent: content,
        execute: h.call,
        onUpdate: s.touch,
      );

  // ---------------------------------------------------------------------------
  // Run A

  Future<void> checkIn(SimWeek w, {required bool isClose}) async {
    final run = AgentRun(RunKind.checkIn);
    final since = w.since.add(const Duration(minutes: 1));
    final item = FeedItem(
      type: FeedType.checkIn,
      title: isClose ? 'October close · numbers are in' : '${w.label} check-in · ${_short.format(since)}–${_short.format(w.until)}',
      date: s.today,
      run: run,
    )..offersReport = isClose;
    s.addFeed(item);

    await _go(
      run,
      isClose ? 'Closing the month…' : 'Checking in for ${w.label}…',
      (h) async {
        run.summary = await _loop(
          run,
          h,
          [listSourcesTool, fetchSourceTool, ledgerSearchTool, ledgerProposeTool, suggestKpiTool, askFounderTool],
          [
            checkInPrompt(
              date: _day.format(s.today),
              label: w.label,
              since: _day.format(since),
              until: _day.format(w.until),
              kpis: s.kpis.toList(),
              isClose: isClose,
            ),
          ],
        );
      },
      (h) => scriptedCheckIn(s, h, w, since, isClose),
    );
    item.body = run.summary;
    s.touch();
  }

  // ---------------------------------------------------------------------------
  // Run B

  Future<void> anomaly(SimWeek w, (Fact, Fact) drop) async {
    final (prev, curr) = drop;
    final pct = ((1 - curr.value! / prev.value!) * 100).round();
    final run = AgentRun(RunKind.anomaly);
    final item = FeedItem(
      type: FeedType.approval,
      title: 'Demo bookings dropped $pct% · investigating',
      date: s.today,
      run: run,
    );
    s.addFeed(item);
    final since = w.since.add(const Duration(minutes: 1));
    await _go(
      run,
      'Investigating the drop in demos…',
      (h) async {
        run.summary = await _loop(
          run,
          h,
          [fetchSourceTool, ledgerSearchTool, teamDirectoryTool, messageTeammateTool],
          [
            anomalyPrompt(
              date: _day.format(s.today),
              detail: 'weekly demo bookings fell from ${prev.value!.round()} (${prev.id}) to ${curr.value!.round()} '
                  '(${curr.id}), −$pct% week over week.',
              since: _day.format(since),
              until: _day.format(w.until),
            ),
          ],
        );
        if (run.messageIds.isEmpty) throw ClaudeException('Agent did not draft a message');
      },
      (h) => scriptedAnomaly(s, h, w, since, prev, curr),
    );
    final to = run.messageIds.isEmpty ? null : s.messageById(run.messageIds.first)?.to;
    item.title = 'Demo bookings dropped $pct%${to == null ? '' : ' · ask $to?'}';
    item.body = run.summary;
    s.touch();
  }

  // ---------------------------------------------------------------------------
  // Run C

  Future<void> inbound(String text, {required String sourceId, required String from, OutboundMessage? replyTo, String? docName}) async {
    final run = AgentRun(RunKind.inbound);
    final channel = switch (sourceId) {
      'voice' => 'voice note',
      'slack' => 'Slack reply',
      'document' => 'document${docName == null ? '' : ' "$docName"'}',
      _ => 'chat',
    };
    final item = FeedItem(
      type: FeedType.inbound,
      title: replyTo != null ? '$from replied on ${replyTo.channel}' : 'You added via $channel',
      date: s.today,
      run: run,
      userText: text,
      author: replyTo != null ? from : null,
    );
    s.addFeed(item);
    final ref = '${sourceId == 'slack' ? 'slack-${replyTo?.id ?? 'msg'}' : '$sourceId-${s.today.month}${s.today.day}-${s.feed.length}'}';
    await _go(
      run,
      'Processing your input…',
      (h) async {
        h.inboundExcerpt = '$from via $channel: $text';
        run.summary = await _loop(
          run,
          h,
          [ledgerSearchTool, ledgerProposeTool, askFounderTool],
          [
            inboundPrompt(
              date: _day.format(s.today),
              from: from,
              channel: channel,
              sourceId: sourceId,
              ref: ref,
              text: text,
            ),
          ],
        );
      },
      (h) {
        h.inboundExcerpt = '$from via $channel: $text';
        return scriptedInbound(s, h, text, sourceId: sourceId, from: from, ref: ref);
      },
    );
    item.body = run.summary;
    s.touch();
  }

  Future<void> document(String name, Uint8List bytes, String mime) async {
    if (mime == 'application/pdf' && live) {
      // PDF goes to Claude as a document block; text files go through inbound().
      final run = AgentRun(RunKind.inbound);
      final item = FeedItem(type: FeedType.inbound, title: 'You added a document', date: s.today, run: run, userText: name);
      s.addFeed(item);
      final ref = 'doc-${name.replaceAll(RegExp(r'\W+'), '-')}';
      await _go(
        run,
        'Reading $name…',
        (h) async {
          h.inboundExcerpt = 'Document: $name';
          run.summary = await _loop(run, h, [ledgerSearchTool, ledgerProposeTool, askFounderTool], [
            {
              'type': 'document',
              'source': {'type': 'base64', 'media_type': 'application/pdf', 'data': base64Encode(bytes)},
            },
            {
              'type': 'text',
              'text': inboundPrompt(
                date: _day.format(s.today),
                from: 'Lena',
                channel: 'document "$name" (attached)',
                sourceId: 'document',
                ref: ref,
                text: '(see the attached PDF)',
              ),
            },
          ]);
        },
        (h) => scriptedInbound(s, h, 'Document $name', sourceId: 'document', from: 'Lena', ref: ref),
      );
      item.body = run.summary;
      s.touch();
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    await inbound(text.length > 20000 ? text.substring(0, 20000) : text, sourceId: 'document', from: 'Lena', docName: name);
  }

  // ---------------------------------------------------------------------------
  // Run D

  Future<void> report() async {
    final run = AgentRun(RunKind.report);
    final item = FeedItem(type: FeedType.report, title: 'Drafting the October update…', date: s.today, run: run);
    s.addFeed(item);
    final kpis = s.buildKpiRows();
    Report? built;

    await _go(
      run,
      'Drafting the October update…',
      (h) async {
        final confirmed = s.facts.where((f) => f.status == FactStatus.confirmed).map((f) => f.toJson()).toList();
        final kpiTable = kpis.map((k) => '${k.label}: ${k.prev ?? '–'} → ${k.curr ?? '–'} (${k.change ?? ''})').join('\n');
        final asked = s.facts
            .where((f) => f.status != FactStatus.dismissed && f.text.toLowerCase().contains('asked for'))
            .map((f) => f.text)
            .toList();
        await _loop(run, h, [submitReportTool], [
          reportPrompt(factsJson: jsonEncode(confirmed), kpiTable: kpiTable, askedFor: asked),
        ]);
        if (h.submittedReport.isEmpty) throw ClaudeException('Agent did not submit a report');
        built = reportFromSubmission(h.submittedReport.last, kpis);
        s.report = built;
        s.touch();
        _deterministicVerify(built!);

        // Separate verifier call.
        run.steps.add(RunStep(type: StepType.model, name: 'verifier', input: 'Separate verifier call'));
        final claims = built!.allClaims.toList();
        final claimsJson = jsonEncode([
          for (var i = 0; i < claims.length; i++)
            {
              'claim_id': 'C${i + 1}',
              'text': claims[i].text,
              'cited_facts': [for (final id in claims[i].factIds) s.factById(id)?.toJson()],
            },
        ]);
        final vHost = ToolHost(s, run);
        await claude.runLoop(
          run: run,
          system: 'You verify investor updates against a fact ledger. Be strict and brief.',
          tools: [verifyClaimsTool],
          userContent: [verifyPrompt(claimsJson: claimsJson)],
          execute: vHost.call,
          onUpdate: s.touch,
        );
        for (final v in vHost.verdicts) {
          final idx = int.tryParse('${v['claim_id']}'.replaceAll(RegExp(r'\D'), ''));
          if (idx == null || idx < 1 || idx > claims.length) continue;
          final c = claims[idx - 1];
          final status = v['status'];
          if (status == 'unsupported' || (status == 'weak' && c.flag == ClaimFlag.none)) {
            c.flag = status == 'unsupported' ? ClaimFlag.unsupported : ClaimFlag.weak;
            c.flagReason = v['reason'] as String?;
          }
        }
        built!.verified = true;
      },
      (h) async {
        built = await scriptedReport(s, h, kpis);
        s.report = built;
        _deterministicVerify(built!);
        await scriptedVerify(s, h, built!);
        built!.verified = true;
      },
    );
    final r = s.report;
    item.title = 'October update ready for approval';
    item.body = r == null
        ? 'Something went wrong while drafting.'
        : 'The October update is ready. Every number links to its source. '
            '${r.flaggedCount == 0 ? 'The verifier found no issues.' : 'I flagged ${r.flaggedCount} claim${r.flaggedCount == 1 ? '' : 's'} for you to check.'}';
    s.touch();
  }

  Report reportFromSubmission(Map<String, dynamic> sub, List<KpiRow> kpis) {
    List<Claim> claims(String key) => [
          for (final c in ((sub[key] as List?) ?? const []).cast<Map<String, dynamic>>())
            Claim(
              text: '${c['text']}',
              factIds: [
                for (final id in ((c['fact_ids'] as List?) ?? const []))
                  if (s.factById('$id') != null) '$id',
              ],
            ),
        ];
    return Report(
      period: 'October 2026',
      subject: '${sub['subject'] ?? 'Shelfwise – October 2026 update'}',
      kpis: kpis,
      sections: [
        ReportSection('TL;DR', claims('tldr')),
        ReportSection('Highlights', claims('highlights')),
        ReportSection('Lowlights', claims('lowlights')),
        ReportSection('Product', claims('product')),
        ReportSection('Team', claims('team')),
        ReportSection('Asks', claims('asks')),
      ],
    );
  }

  /// Rules that never depend on the model.
  void _deterministicVerify(Report r) {
    for (final c in r.allClaims) {
      final cited = c.factIds.map(s.factById).whereType<Fact>().toList();
      if (cited.isEmpty) {
        c.flag = ClaimFlag.unsupported;
        c.flagReason = 'No fact cited.';
        continue;
      }
      final unconfirmed = cited.where((f) => f.status != FactStatus.confirmed);
      if (unconfirmed.isNotEmpty) {
        c.flag = ClaimFlag.unsupported;
        c.flagReason = 'Cites a fact that is not confirmed (${unconfirmed.first.id}).';
        continue;
      }
      final said = cited.where((f) => f.statementOnly);
      if (said.isNotEmpty) {
        final f = said.first;
        c.flag = ClaimFlag.weak;
        c.flagReason = '"${f.text}" was only said in a ${f.sourceId == 'jamie' ? 'meeting (Jamie)' : f.sourceId}, '
            'not confirmed in the CRM or a contract.';
      }
    }
  }
}
