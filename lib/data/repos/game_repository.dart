import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids.dart';

/// High-score storage for Tsumiki Towers (SPEC §5.6); rows carry an
/// Arena-ready `submitted` flag for the online leaderboard (§5.7).
class GameRepository {
  GameRepository(this._db);

  final AppDatabase _db;

  Future<String> saveScore({
    String mode = 'survival',
    required int score,
    required int piecesPlaced,
    required int durationSeconds,
  }) async {
    final id = newId();
    await _db.into(_db.gameScores).insert(GameScoresCompanion.insert(
          id: id,
          mode: Value(mode),
          score: score,
          piecesPlaced: Value(piecesPlaced),
          durationSeconds: Value(durationSeconds),
          playedAt: DateTime.now(),
        ));
    return id;
  }

  Stream<List<GameScore>> watchTopScores({String mode = 'survival', int limit = 8}) {
    return (_db.select(_db.gameScores)
          ..where((s) => s.deletedAt.isNull() & s.mode.equals(mode))
          ..orderBy([
            (s) => OrderingTerm.desc(s.score),
            (s) => OrderingTerm.asc(s.playedAt),
          ])
          ..limit(limit))
        .watch();
  }

  /// Scores not yet pushed to the Arena leaderboard.
  Future<List<GameScore>> unsubmittedScores() {
    return (_db.select(_db.gameScores)
          ..where((s) => s.deletedAt.isNull() & s.submitted.equals(false)))
        .get();
  }

  Future<void> markSubmitted(String id) {
    return (_db.update(_db.gameScores)..where((s) => s.id.equals(id))).write(
      GameScoresCompanion(
        submitted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
