enum FactStatus { pending, confirmed, dismissed }

enum FactKind { kpi, highlight, lowlight, product, team, ask, context }

FactKind factKindFrom(String? s) =>
    FactKind.values.firstWhere((k) => k.name == s, orElse: () => FactKind.context);

/// One atomic, sourced statement in the ledger. Reports are built only from
/// confirmed facts.
class Fact {
  Fact({
    required this.id,
    required this.text,
    required this.kind,
    required this.sourceId,
    required this.sourceRef,
    required this.owner,
    required this.date,
    this.metric,
    this.value,
    this.unit,
    this.period,
    this.excerpt,
    this.statementOnly = false,
    this.status = FactStatus.pending,
  });

  final String id;
  String text;
  FactKind kind;
  String? metric;
  double? value;
  String? unit;

  /// For KPI facts: the reporting period this value belongs to, e.g. 2026-10.
  String? period;
  final String sourceId;
  final String sourceRef;
  final String owner;
  final DateTime date;

  /// Raw text from the source that backs this fact (shown on click).
  String? excerpt;

  /// Said in a meeting or chat, but not backed by a system of record.
  bool statementOnly;
  FactStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'kind': kind.name,
        if (metric != null) 'metric': metric,
        if (value != null) 'value': value,
        if (unit != null) 'unit': unit,
        if (period != null) 'period': period,
        'source': sourceId,
        'source_ref': sourceRef,
        'owner': owner,
        'date': date.toIso8601String().substring(0, 10),
        'status': status.name,
        if (statementOnly) 'statement_only': true,
      };
}
