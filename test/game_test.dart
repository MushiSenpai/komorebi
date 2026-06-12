import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/game_repository.dart';
import 'package:komorebi/features/play/game/pieces.dart';
import 'package:komorebi/features/play/game/tower_world.dart';

void main() {
  group('pieces', () {
    test('all seven tetrominoes have four cells each', () {
      expect(PieceSpec.all, hasLength(7));
      for (final piece in PieceSpec.all) {
        expect(piece.cells, hasLength(4), reason: piece.name);
        expect(piece.cells.toSet(), hasLength(4),
            reason: '${piece.name} has overlapping cells');
      }
    });

    test('descent ramps every five pieces and never maxes out', () {
      expect(TowerWorld.descentSpeedFor(0), 1.4, reason: 'gentle start');
      expect(TowerWorld.descentSpeedFor(4), 1.4);
      expect(TowerWorld.descentSpeedFor(5), closeTo(1.65, 0.001));
      expect(TowerWorld.descentSpeedFor(10), closeTo(1.9, 0.001));
      expect(TowerWorld.descentSpeedFor(500), 3.2,
          reason: 'capped — it should stay playable forever');
    });

    test('camera keeps the island low with sky above', () {
      final world = TowerWorld(seed: 1);
      expect(world.cameraTargetY, lessThanOrEqualTo(-3.5),
          reason: 'screen centre sits well above the island');
    });

    test('height converts to whole blocks', () {
      expect(heightToBlocks(-1), 0);
      expect(heightToBlocks(0), 0);
      expect(heightToBlocks(0.59), 0);
      expect(heightToBlocks(0.6), 1);
      expect(heightToBlocks(3.05), 5);
    });
  });

  group('score repository', () {
    late AppDatabase db;
    late GameRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = GameRepository(db);
    });
    tearDown(() => db.close());

    test('top scores order by height, ties by earliest', () async {
      await repo.saveScore(score: 5, piecesPlaced: 9, durationSeconds: 60);
      await repo.saveScore(score: 12, piecesPlaced: 20, durationSeconds: 140);
      await repo.saveScore(score: 12, piecesPlaced: 25, durationSeconds: 150);

      final top = await repo.watchTopScores().first;
      expect(top.map((s) => s.score), [12, 12, 5]);
      expect(top.first.piecesPlaced, 20, reason: 'earlier 12 ranks first');
    });

    test('scores start unsubmitted and can be marked for Arena', () async {
      final id =
          await repo.saveScore(score: 7, piecesPlaced: 11, durationSeconds: 80);
      expect(await repo.unsubmittedScores(), hasLength(1));
      await repo.markSubmitted(id);
      expect(await repo.unsubmittedScores(), isEmpty);
    });
  });
}
