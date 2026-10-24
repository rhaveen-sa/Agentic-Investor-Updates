import '../app_state.dart';
import '../data/connectors.dart';
import '../models/fact.dart';
import '../models/agent_run.dart';

/// The app never shows em or en dashes; agent text is cleaned on the way in.
String noDashes(String s) => s.replaceAll(RegExp(r'\s*[—–]\s*'), ', ');

Map<String, dynamic> _tool(String name, String description, Map<String, dynamic> props, List<String> required) => {
      'name': name,
      'description': description,
      'input_schema': {
        'type': 'object',
        'properties': props,
        'required': required,
        'additionalProperties': false,
      },
    };

const _str = {'type': 'string'};

final listSourcesTool = _tool('list_sources', 'List the connected data sources.', {}, []);

final fetchSourceTool = _tool(
  'fetch_source',
  'Read one connected source for a period. Returns raw records (releases, deals, meeting notes, '
      'weekly stats, finance). Dates are YYYY-MM-DD, both inclusive. You can only see data up to today.',
  {
    'source': {
      'type': 'string',
      'enum': ['github', 'jamie', 'hubspot', 'linkedin', 'stripe', 'packages'],
    },
    'since': _str,
    'until': _str,
  },
  ['source', 'since', 'until'],
);

final ledgerSearchTool = _tool(
  'ledger_search',
  'Search the fact ledger (all non-dismissed facts, any status). Use it to avoid duplicates and find context.',
  {'query': _str},
  ['query'],
);

final ledgerProposeTool = _tool(
  'ledger_propose',
  'Add a fact to the ledger as "pending". The founder confirms it later. One atomic, sourced statement per call. '
      'Always set source_ref to the record id the fact comes from.',
  {
    'text': {'type': 'string', 'description': 'Short investor-ready statement, with the number.'},
    'kind': {
      'type': 'string',
      'enum': ['kpi', 'highlight', 'lowlight', 'product', 'team', 'ask', 'context'],
    },
    'source': {
      'type': 'string',
      'enum': ['github', 'jamie', 'hubspot', 'linkedin', 'stripe', 'packages', 'founder', 'voice', 'document', 'slack'],
    },
    'source_ref': {'type': 'string', 'description': 'Record id from the source, e.g. hs-deal-1160.'},
    'owner': {'type': 'string', 'enum': ['Thomas', 'Jarno', 'Mirte']},
    'metric': {
      'type': 'string',
      'description': 'Optional metric key: arr, customers, nrr, demos, burn, cash, runway (monthly KPIs, need period), '
          'demos_week (weekly demo bookings), new_arr, churned_arr.',
    },
    'value': {'type': 'number', 'description': 'Raw number: EUR as full amount (668000), % as 108, months as 16.'},
    'unit': {'type': 'string', 'enum': ['EUR', '%', 'months', 'teams', 'demos']},
    'period': {'type': 'string', 'description': 'For monthly KPIs: YYYY-MM.'},
    'statement_only': {
      'type': 'boolean',
      'description': 'True if this was only said (meeting, chat) and is not backed by a system of record or contract.',
    },
  },
  ['text', 'kind', 'source', 'source_ref', 'owner'],
);

final suggestKpiTool = _tool(
  'suggest_kpi',
  'Suggest adding a metric to the fixed KPI set of the investor update, e.g. because an investor asked for it.',
  {
    'metric': {'type': 'string', 'enum': kpiCatalog.keys.toList()},
    'reason': _str,
    'fact_id': {'type': 'string', 'description': 'Ledger fact that motivates this.'},
  },
  ['metric', 'reason'],
);

final teamDirectoryTool = _tool('team_directory', 'Who owns which area, and how to reach them.', {}, []);

final askFounderTool = _tool(
  'ask_founder',
  'Put 1 to 3 short, targeted questions for the founder into the feed. Only ask what the sources cannot answer.',
  {
    'questions': {'type': 'array', 'items': _str},
  },
  ['questions'],
);

final messageTeammateTool = _tool(
  'message_teammate',
  'Draft a message to a teammate on the founder\'s behalf. It is NOT sent until the founder approves it.',
  {
    'person': {'type': 'string', 'enum': ['Jarno', 'Mirte']},
    'channel': {'type': 'string', 'enum': ['Slack', 'WhatsApp', 'Email']},
    'text': {'type': 'string', 'description': 'Friendly, short, specific: state what you saw and what you need.'},
    'reason': {'type': 'string', 'description': 'One line for the founder on why you want to send this.'},
  },
  ['person', 'channel', 'text', 'reason'],
);

final _claim = {
  'type': 'object',
  'properties': {
    'text': _str,
    'fact_ids': {'type': 'array', 'items': _str},
  },
  'required': ['text', 'fact_ids'],
  'additionalProperties': false,
};

final submitReportTool = _tool(
  'submit_report',
  'Submit the investor update. Every claim must cite the confirmed ledger fact ids it is based on. '
      'The KPI table is added automatically from the ledger, do not write it.',
  {
    'subject': _str,
    'tldr': {'type': 'array', 'items': _claim, 'description': 'Exactly 3 bullets.'},
    'highlights': {'type': 'array', 'items': _claim},
    'lowlights': {'type': 'array', 'items': _claim},
    'product': {'type': 'array', 'items': _claim},
    'team': {'type': 'array', 'items': _claim},
    'asks': {'type': 'array', 'items': _claim},
  },
  ['subject', 'tldr', 'highlights', 'lowlights', 'product', 'team', 'asks'],
);

final verifyClaimsTool = _tool(
  'verify_claims',
  'Return a verdict for every claim of the report.',
  {
    'results': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'claim_id': _str,
          'status': {'type': 'string', 'enum': ['supported', 'weak', 'unsupported']},
          'reason': _str,
        },
        'required': ['claim_id', 'status', 'reason'],
        'additionalProperties': false,
      },
    },
  },
  ['results'],
);

DateTime _parseDay(String s, {bool end = false}) {
  final d = DateTime.parse(s.length > 10 ? s.substring(0, 10) : s);
  return end ? DateTime(d.year, d.month, d.day, 23, 59, 59) : d.subtract(const Duration(seconds: 1));
}

/// Executes tool calls against the local app state. Shared by the live agent
/// and the scripted fallback, so both produce identical results.
class ToolHost {
  ToolHost(this.s, this.run);

  final AppState s;
  final AgentRun run;
  final List<Map<String, dynamic>> submittedReport = [];
  final List<Map<String, dynamic>> verdicts = [];

  /// For inbound runs: the message the facts are extracted from.
  String? inboundExcerpt;
  DateTime? inboundDate;

  Future<Object?> call(String name, Map<String, dynamic> input) async {
    switch (name) {
      case 'list_sources':
        return [
          for (final id in s.connectors.keys)
            {'id': id, 'name': sourceInfo(id).name, 'category': sourceInfo(id).category},
        ];
      case 'fetch_source':
        final id = input['source'] as String;
        final c = s.connectors[id];
        if (c == null) throw 'Unknown source $id';
        var until = _parseDay(input['until'] as String, end: true);
        final todayEnd = DateTime(s.today.year, s.today.month, s.today.day, 23, 59, 59);
        if (until.isAfter(todayEnd)) until = todayEnd;
        final items = await c.fetch(_parseDay(input['since'] as String), until);
        return {'source': id, 'records': [for (final i in items) i.toAgentJson()]};
      case 'ledger_search':
        return [for (final f in s.search(input['query'] as String? ?? '').take(25)) f.toJson()];
      case 'ledger_propose':
        return _propose(input);
      case 'suggest_kpi':
        s.addKpiSuggestion(input['metric'] as String, input['reason'] as String? ?? '', input['fact_id'] as String?);
        return {'status': 'suggested to founder'};
      case 'team_directory':
        return [for (final t in teamDirectory) t.toJson()];
      case 'ask_founder':
        final qs = ((input['questions'] as List?) ?? const []).map((q) => '$q').toList();
        run.questions.addAll(qs.take(3).map(noDashes));
        return {'status': 'questions shown to founder'};
      case 'message_teammate':
        final m = s.draftMessage(
          input['person'] as String,
          input['channel'] as String? ?? 'Slack',
          noDashes(input['text'] as String),
          input['reason'] as String?,
        );
        run.messageIds.add(m.id);
        return {'message_id': m.id, 'status': 'draft, waiting for founder approval'};
      case 'submit_report':
        submittedReport.add(input);
        return {'status': 'received'};
      case 'verify_claims':
        verdicts.addAll(((input['results'] as List?) ?? const []).cast<Map<String, dynamic>>());
        return {'status': 'received'};
    }
    throw 'Unknown tool $name';
  }

  Future<Map<String, dynamic>> _propose(Map<String, dynamic> input) async {
    final text = noDashes(input['text'] as String);
    final ref = input['source_ref'] as String? ?? 'unknown';
    final metric = input['metric'] as String?;
    final period = input['period'] as String?;

    // Dedupe: same record + same metric, or same record + same text.
    for (final f in s.activeFacts) {
      final sameRecord = f.sourceRef == ref;
      final sameMetric = metric != null && f.metric == metric && f.period == period && period != null;
      if ((sameRecord && ((metric != null && f.metric == metric) || f.text == text)) || sameMetric) {
        return {'id': f.id, 'status': 'duplicate of existing fact', 'existing': f.toJson()};
      }
    }
    final sourceId = input['source'] as String? ?? 'founder';
    String? excerpt;
    final item = await s.connectors[sourceId]?.byId(ref);
    if (item != null) excerpt = '${item.title}\n${item.body}';
    final f = s.addFact(
      text: text,
      kind: factKindFrom(input['kind'] as String?),
      sourceId: sourceId,
      sourceRef: ref,
      owner: input['owner'] as String? ?? 'Thomas',
      date: item?.ts ?? inboundDate ?? s.today,
      metric: metric,
      value: (input['value'] as num?)?.toDouble(),
      unit: input['unit'] as String?,
      period: period,
      excerpt: excerpt ?? inboundExcerpt,
      statementOnly: input['statement_only'] as bool? ?? false,
    );
    run.proposedFactIds.add(f.id);
    return {'id': f.id, 'status': 'pending'};
  }
}
