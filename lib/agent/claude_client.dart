import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent_run.dart';

const anthropicApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const claudeModel = 'claude-sonnet-5-5';

class ClaudeException implements Exception {
  ClaudeException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef ToolExecutor = Future<Object?> Function(String name, Map<String, dynamic> input);

/// Minimal Messages API client with a manual tool-use loop. Every model call
/// and tool call is recorded on the [AgentRun] so the UI can show the trace.
class ClaudeClient {
  ClaudeClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  bool get hasKey => anthropicApiKey.isNotEmpty;

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final res = await _http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': anthropicApiKey,
            'anthropic-version': '2023-06-01',
            'anthropic-beta': 'server-side-fallback-2026-07-01',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = decoded['error'] as Map<String, dynamic>?;
      throw ClaudeException('Claude API ${res.statusCode}: ${err?['message'] ?? res.body}');
    }
    return decoded;
  }

  /// Runs the agent until it stops calling tools. Returns the final text.
  Future<String> runLoop({
    required AgentRun run,
    required String system,
    required List<Map<String, dynamic>> tools,
    required List<Object> userContent,
    required ToolExecutor execute,
    void Function()? onUpdate,
    int maxIterations = 12,
  }) async {
    if (!hasKey) throw ClaudeException('No ANTHROPIC_API_KEY set');
    final messages = <Map<String, dynamic>>[
      {'role': 'user', 'content': userContent},
    ];
    var finalText = '';
    for (var i = 0; i < maxIterations; i++) {
      final step = RunStep(type: StepType.model, name: claudeModel, input: 'turn ${i + 1}');
      run.steps.add(step);
      onUpdate?.call();
      final sw = Stopwatch()..start();
      final res = await _post({
        'model': claudeModel,
        'max_tokens': 8000,
        'system': system,
        'tools': tools,
        'tool_choice': {'type': 'auto'},
        'output_config': {'effort': 'medium'},
        'fallbacks': 'default',
        'messages': messages,
      });
      step.ms = sw.elapsedMilliseconds;
      final content = (res['content'] as List).cast<Map<String, dynamic>>();
      final stop = res['stop_reason'];
      final usage = res['usage'] as Map<String, dynamic>?;
      final text = content.where((b) => b['type'] == 'text').map((b) => b['text']).join('\n').trim();
      final toolUses = content.where((b) => b['type'] == 'tool_use').toList();
      step.output = {
        'stop_reason': stop,
        if (text.isNotEmpty) 'text': text,
        if (toolUses.isNotEmpty) 'tool_calls': [for (final t in toolUses) t['name']],
        if (usage != null) 'tokens': {'in': usage['input_tokens'], 'out': usage['output_tokens']},
      };
      if (text.isNotEmpty) finalText = text;
      if (stop == 'refusal') throw ClaudeException('Model declined the request');

      // Pass the assistant content back unchanged (thinking blocks included).
      messages.add({'role': 'assistant', 'content': content});
      if (stop != 'tool_use' || toolUses.isEmpty) break;

      final results = <Map<String, dynamic>>[];
      for (final t in toolUses) {
        final name = t['name'] as String;
        final input = (t['input'] as Map?)?.cast<String, dynamic>() ?? {};
        final toolStep = RunStep(type: StepType.tool, name: name, input: input);
        run.steps.add(toolStep);
        onUpdate?.call();
        final tsw = Stopwatch()..start();
        try {
          final out = await execute(name, input);
          toolStep.output = out;
          results.add({'type': 'tool_result', 'tool_use_id': t['id'], 'content': jsonEncode(out)});
        } catch (e) {
          toolStep.output = {'error': e.toString()};
          results.add({'type': 'tool_result', 'tool_use_id': t['id'], 'content': 'Error: $e', 'is_error': true});
        }
        toolStep.ms = tsw.elapsedMilliseconds;
        onUpdate?.call();
      }
      messages.add({'role': 'user', 'content': results});
    }
    return finalText;
  }
}
