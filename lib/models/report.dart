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
    this.burn = 0,
    this.cash = 0,
    this.maxBurn = 0,
    this.projection = const [],
    this.edge = const [],
    this.history = const [],
  });

  final bool alive;
  final double monthlyGrowth; // this month's ARR growth, e.g. 0.173
  final int months; // months to break-even if alive, to zero cash if dead
  final double cashLeft; // cash at break-even (alive only)
  final double minGrowth; // lowest steady monthly growth that still reaches break-even
  final List<String> factIds;
  final double burn; // October net burn
  final double cash; // October cash
  final double maxBurn; // highest burn that stays alive at this growth
  /// Month 0 = October 2026, flat expenses, revenue growing at [monthlyGrowth].
  final List<ProjectionPoint> projection;
  /// The dead/alive boundary: minimum steady growth for each burn level.
  final List<({double burn, double growth})> edge;
  /// Actual closes before October (September), for charts that start there.
  final List<ProjectionPoint> history;
}

class ProjectionPoint {
  const ProjectionPoint(this.month, this.revenue, this.expenses, this.cash);

  /// Months after October 2026; -1 is September.
  final int month;
  final double revenue;
  final double expenses;
  final double cash;
}

/// One line of the customers table, read from confirmed new_arr / churned_arr facts.
class CustomerRow {
  CustomerRow({required this.name, required this.detail, required this.arr, required this.factId});

  final String name;
  final String detail;
  final double arr;
  final String factId;
  bool get lost => arr < 0;
}

/// September ARR plus new minus churned ARR, checked against October ARR.
class ArrBridge {
  ArrBridge({required this.start, required this.end, required this.rows, required this.startFactId, required this.endFactId});

  final double start;
  final double end;
  final List<CustomerRow> rows;
  final String startFactId;
  final String endFactId;
  double get sum => start + rows.fold(0.0, (a, r) => a + r.arr);
  bool get reconciles => (sum - end).abs() < 1;
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
  ArrBridge? bridge;

  Iterable<Claim> get allClaims => sections.expand((s) => s.claims);
  int get flaggedCount => allClaims.where((c) => c.flag != ClaimFlag.none).length;
}
