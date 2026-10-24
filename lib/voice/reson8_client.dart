import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const reson8ApiKey = String.fromEnvironment('RESON8_API_KEY');
const _base = 'https://api.reson8.dev/v1';

/// Startup jargon and names the transcription should get right.
const startupVocabulary = [
  'ARR', 'MRR', 'NRR', 'net revenue retention', 'churn', 'runway', 'net burn', 'burn rate', 'CAC', 'LTV',
  'payback', 'pipeline', 'seed round', 'Series A', 'term sheet', 'cap table', 'SAFE', 'ESOP',
  'Shelfwise', 'FreshMart Nord', 'Northstar Ventures', 'Lena', 'Tom', 'Anna', 'Mara',
  'backend engineers', 'ML engineer', 'pilot', 'Release 2.0', 'LinkedIn', 'HubSpot', 'Stripe', 'Jamie',
  '171k', '668k', 'k ARR',
];

/// Record from the mic, then transcribe with Reson8 (prerecorded endpoint,
/// biased with a custom model built from [startupVocabulary]).
class Reson8Client {
  final _recorder = AudioRecorder();
  String? _path;
  String? _customModelId;
  bool _modelTried = false;

  bool get hasKey => reson8ApiKey.isNotEmpty;

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1), path: _path!);
    return true;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
  }

  /// Stops recording and returns the transcript.
  Future<String> stopAndTranscribe() async {
    final path = await _recorder.stop() ?? _path;
    if (path == null) throw Exception('No recording');
    final bytes = await File(path).readAsBytes();
    if (!hasKey) throw Exception('No RESON8_API_KEY set');
    await _ensureCustomModel();
    final uri = Uri.parse('$_base/speech-to-text/prerecorded').replace(queryParameters: {
      'encoding': 'm4a',
      'language': 'en',
      'custom_model_id': ?_customModelId,
    });
    final res = await http
        .post(uri,
            headers: {'Authorization': 'ApiKey $reson8ApiKey', 'Content-Type': 'application/octet-stream'}, body: bytes)
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Reson8 ${res.statusCode}: ${res.body}');
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (json['text'] as String? ?? '').trim();
  }

  Future<void> _ensureCustomModel() async {
    if (_modelTried) return;
    _modelTried = true;
    try {
      final res = await http
          .post(
            Uri.parse('$_base/custom-model'),
            headers: {'Authorization': 'ApiKey $reson8ApiKey', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': 'shelfwise-investor-updates',
              'description': 'Startup finance and investor-update vocabulary for Shelfwise',
              'phrases': startupVocabulary,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _customModelId = (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String?;
      } else {
        debugPrint('Reson8 custom model: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('Reson8 custom model failed: $e');
    }
  }
}
