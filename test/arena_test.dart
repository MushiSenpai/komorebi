import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:komorebi/features/play/game/pieces.dart';
import 'package:komorebi/services/arena_api.dart';

import 'dart:math';

void main() {
  group('PocketBaseArena', () {
    test('submit posts the score payload', () async {
      late http.Request captured;
      final api = PocketBaseArena(
        'https://arena.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"id":"x"}', 200);
        }),
      );
      await api.submit(
        handle: 'mushi',
        clientId: 'c1',
        mode: 'survival',
        score: 12,
        pieces: 20,
        durationSeconds: 140,
        playedAt: DateTime.utc(2026, 6, 12, 4),
      );
      expect(captured.url.path, '/api/collections/scores/records');
      final body = jsonDecode(captured.body) as Map;
      expect(body['handle'], 'mushi');
      expect(body['score'], 12);
      expect(body['mode'], 'survival');
      expect(body['played_at'], '2026-06-12T04:00:00.000Z');
    });

    test('top dedupes by handle keeping the best, case-insensitive',
        () async {
      final api = PocketBaseArena(
        'https://arena.test',
        client: MockClient((request) async {
          expect(request.url.queryParameters['filter'], "(mode='survival')");
          return http.Response(
              jsonEncode({
                'items': [
                  {'handle': 'Mushi', 'score': 15, 'mode': 'survival'},
                  {'handle': 'kaze', 'score': 12, 'mode': 'survival'},
                  {'handle': 'mushi', 'score': 9, 'mode': 'survival'},
                ]
              }),
              200);
        }),
      );
      final top = await api.top(mode: 'survival');
      expect(top.map((s) => '${s.handle}:${s.score}'),
          ['Mushi:15', 'kaze:12']);
    });

    test('errors surface as ArenaException', () async {
      final api = PocketBaseArena(
        'https://arena.test',
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(() => api.top(mode: 'survival'),
          throwsA(isA<ArenaException>()));
    });
  });

  group('daily duel', () {
    test('mode and seed derive from the UTC date', () {
      final when = DateTime.utc(2026, 6, 12, 23);
      expect(dailyMode(when), 'daily-20260612');
      expect(dailySeed(when), 20260612);
    });

    test('same seed deals the same pieces — fair duels', () {
      List<String> deal(int seed) {
        final rng = Random(seed);
        return [for (var i = 0; i < 12; i++) PieceSpec.random(rng).name];
      }

      expect(deal(20260612), deal(20260612));
      expect(deal(20260612), isNot(deal(20260613)));
    });
  });
}
