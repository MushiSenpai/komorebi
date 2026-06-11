import 'dart:convert';

import 'package:http/http.dart' as http;

/// One leaderboard row.
class ArenaScore {
  const ArenaScore({
    required this.handle,
    required this.score,
    required this.pieces,
    required this.mode,
    required this.playedAt,
  });

  final String handle;
  final int score;
  final int pieces;
  final String mode;
  final DateTime playedAt;
}

/// The Arena backend contract (SPEC §5.7). Swappable by design — v1 talks
/// to a self-hosted PocketBase, a future version could use the sync server.
abstract class ArenaApi {
  Future<void> submit({
    required String handle,
    required String clientId,
    required String mode,
    required int score,
    required int pieces,
    required int durationSeconds,
    required DateTime playedAt,
  });

  /// Best score per player for [mode], tallest first.
  Future<List<ArenaScore>> top({required String mode, int limit = 10});
}

/// PocketBase implementation against the `scores` collection
/// (see server/arena/ for the matching backend setup).
class PocketBaseArena implements ArenaApi {
  PocketBaseArena(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<void> submit({
    required String handle,
    required String clientId,
    required String mode,
    required int score,
    required int pieces,
    required int durationSeconds,
    required DateTime playedAt,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/collections/scores/records'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'handle': handle,
        'client_id': clientId,
        'mode': mode,
        'score': score,
        'pieces': pieces,
        'duration': durationSeconds,
        'played_at': playedAt.toUtc().toIso8601String(),
      }),
    );
    if (response.statusCode >= 300) {
      throw ArenaException(
          'submit failed (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<List<ArenaScore>> top({required String mode, int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/api/collections/scores/records').replace(
      queryParameters: {
        'page': '1',
        'perPage': '60',
        'sort': '-score,played_at',
        'filter': "(mode='$mode')",
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode >= 300) {
      throw ArenaException(
          'leaderboard failed (${response.statusCode}): ${response.body}');
    }
    final items =
        (jsonDecode(response.body)['items'] as List).cast<Map>();
    // Best per handle; items already arrive tallest-first.
    final seen = <String>{};
    final result = <ArenaScore>[];
    for (final item in items) {
      final handle = (item['handle'] ?? '?') as String;
      if (!seen.add(handle.toLowerCase())) continue;
      result.add(ArenaScore(
        handle: handle,
        score: (item['score'] as num).toInt(),
        pieces: (item['pieces'] as num? ?? 0).toInt(),
        mode: (item['mode'] ?? '') as String,
        playedAt:
            DateTime.tryParse((item['played_at'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0),
      ));
      if (result.length >= limit) break;
    }
    return result;
  }
}

class ArenaException implements Exception {
  ArenaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The daily-duel mode id: everyone who plays this mode today gets the same
/// piece sequence (seeded by the date), so scores compare fairly — async
/// multiplayer without realtime infrastructure (SPEC §5.7).
String dailyMode([DateTime? when]) {
  final d = (when ?? DateTime.now()).toUtc();
  return 'daily-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// Deterministic seed for today's duel.
int dailySeed([DateTime? when]) {
  final d = (when ?? DateTime.now()).toUtc();
  return d.year * 10000 + d.month * 100 + d.day;
}
