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

/// Paul Graham's "default alive or default dead" test. Computed in code from
/// confirmed ARR, net burn and cash; the model never writes these numbers.
class DefaultAlive {
  DefaultAlive({
    required this.alive,
    required this.monthlyGrowth,
    required this.months,
    required this.cashLeft,
    required this.minGrowth,
    required this.factIds,
  });

  final bool alive;
  final double monthlyGrowth; // this month's ARR growth, e.g. 0.173
  final int months; // months to break-even if alive, to zero cash if dead
  final double cashLeft; // cash at break-even (alive only)
  final double minGrowth; // lowest steady monthly growth that still reaches break-even
  final List<String> factIds;
}

class Report {
  Report({required this.period, required this.subject, required this.sections, required this.kpis});

  final String period;
  final String subject;
  final List<ReportSection> sections;
  final List<KpiRow> kpis;
  bool approved = false;
  bool verified = false;
  DefaultAlive? defaultAlive;

  Iterable<Claim> get allClaims => sections.expand((s) => s.claims);
  int get flaggedCount => allClaims.where((c) => c.flag != ClaimFlag.none).length;
}
