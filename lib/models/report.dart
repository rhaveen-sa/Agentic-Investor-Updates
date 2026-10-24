enum ClaimFlag { none, weak, unsupported }

class Claim {
  Claim({required this.text, required this.factIds});

  final String text;
  final List<String> factIds;
  ClaimFlag flag = ClaimFlag.none;
  String? flagReason;
}

class ReportSection {
  ReportSection(this.title, this.claims);

  final String title;
  final List<Claim> claims;
}

class KpiRow {
  KpiRow({required this.label, this.prev, this.curr, this.change, this.prevFactId, this.currFactId});

  final String label;
  final String? prev;
  final String? curr;
  final String? change;
  final String? prevFactId;
  final String? currFactId;
}

class Report {
  Report({required this.period, required this.subject, required this.sections, required this.kpis});

  final String period;
  final String subject;
  final List<ReportSection> sections;
  final List<KpiRow> kpis;
  bool approved = false;
  bool verified = false;

  Iterable<Claim> get allClaims => sections.expand((s) => s.claims);
  int get flaggedCount => allClaims.where((c) => c.flag != ClaimFlag.none).length;
}
