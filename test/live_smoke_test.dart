import 'dart:io';

import 'package:agentic_investor_ai/agent/claude_client.dart';
import 'package:agentic_investor_ai/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the week 1 check-in against the real Claude API.
/// flutter test test/live_smoke_test.dart --dart-define-from-file=secrets.json
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding blocks real HTTP; this test needs the network.
  HttpOverrides.global = null;

  test('week 1 check-in runs live on Claude', () async {
    final s = AppState();
    await s.reset();
    s.scripted = false;
    await s.runCheckIn();
    final run = s.feed.firstWhere((f) => f.run != null).run!;
    for (final step in run.steps) {
      // ignore: avoid_print
      print('${step.type.name} ${step.name}');
    }
    expect(run.error, isNull, reason: run.error);
    expect(run.scripted, isFalse);
    expect(run.proposedFactIds, isNotEmpty);
  }, skip: !ClaudeClient().hasKey, timeout: const Timeout(Duration(minutes: 3)));
}
