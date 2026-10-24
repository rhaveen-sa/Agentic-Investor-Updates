import 'dart:convert';

enum RunKind { checkIn, anomaly, inbound, report }

extension RunKindLabel on RunKind {
  String get label => switch (this) {
        RunKind.checkIn => 'Run A · Weekly check-in',
        RunKind.anomaly => 'Run B · Anomaly investigation',
        RunKind.inbound => 'Run C · Inbound processing',
        RunKind.report => 'Run D · Period report',
      };
}

enum StepType { model, tool }

class RunStep {
  RunStep({required this.type, required this.name, this.input, this.output, this.ms = 0});

  final StepType type;
  final String name;
  Object? input;
  Object? output;
  int ms;

  String get inputPretty => _pretty(input);
  String get outputPretty => _pretty(output);

  static String _pretty(Object? o) {
    if (o == null) return '';
    if (o is String) return o;
    return const JsonEncoder.withIndent('  ').convert(o);
  }
}

class AgentRun {
  AgentRun(this.kind, {this.scripted = false});

  final RunKind kind;
  final bool scripted;
  final List<RunStep> steps = [];
  final List<String> proposedFactIds = [];
  final List<String> questions = [];
  final List<String> messageIds = [];
  String? summary;
  String? error;
  bool done = false;

  int get modelCalls => steps.where((s) => s.type == StepType.model).length;
  int get toolCalls => steps.where((s) => s.type == StepType.tool).length;
}
