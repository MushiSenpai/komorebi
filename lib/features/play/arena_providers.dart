import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ids.dart';
import '../../data/providers.dart';
import '../../data/repos/game_repository.dart';
import '../../services/arena_api.dart';
import 'play_screen.dart' show gameRepositoryProvider;

/// Default self-hosted Arena endpoint; override via the `arena_url` setting.
const defaultArenaUrl = 'https://arena.theinvalid.me';

typedef ArenaConfig = ({bool enabled, String handle, String url});

final arenaApiProvider = Provider<ArenaApi>((ref) {
  final config = ref.watch(arenaConfigProvider).value;
  return PocketBaseArena(config?.url ?? defaultArenaUrl);
});

final arenaConfigProvider =
    AsyncNotifierProvider<ArenaConfigNotifier, ArenaConfig>(
        ArenaConfigNotifier.new);

class ArenaConfigNotifier extends AsyncNotifier<ArenaConfig> {
  @override
  Future<ArenaConfig> build() async {
    final db = ref.watch(databaseProvider);
    return (
      enabled: await db.getSetting('arena_enabled') == '1',
      handle: await db.getSetting('arena_handle') ?? '',
      url: await db.getSetting('arena_url') ?? defaultArenaUrl,
    );
  }

  /// Opt in: store the handle and a stable anonymous client id.
  Future<void> enable(String handle) async {
    final db = ref.read(databaseProvider);
    await db.setSetting('arena_enabled', '1');
    await db.setSetting('arena_handle', handle.trim());
    if (await db.getSetting('arena_client_id') == null) {
      await db.setSetting('arena_client_id', newId());
    }
    ref.invalidateSelf();
  }

  Future<void> disable() async {
    await ref.read(databaseProvider).setSetting('arena_enabled', '0');
    ref.invalidateSelf();
  }
}

/// Pushes locally-saved scores that have not reached the Arena yet.
/// Quietly does nothing when offline or disabled.
final arenaSyncProvider = Provider<ArenaSync>((ref) => ArenaSync(ref));

class ArenaSync {
  ArenaSync(this._ref);

  final Ref _ref;

  Future<int> syncPending() async {
    final config = await _ref.read(arenaConfigProvider.future);
    if (!config.enabled || config.handle.isEmpty) return 0;
    final db = _ref.read(databaseProvider);
    final clientId = await db.getSetting('arena_client_id');
    if (clientId == null) return 0;

    final games = _ref.read(gameRepositoryProvider);
    final api = _ref.read(arenaApiProvider);
    var pushed = 0;
    for (final score in await games.unsubmittedScores()) {
      try {
        await api.submit(
          handle: config.handle,
          clientId: clientId,
          mode: score.mode,
          score: score.score,
          pieces: score.piecesPlaced,
          durationSeconds: score.durationSeconds,
          playedAt: score.playedAt,
        );
        await games.markSubmitted(score.id);
        pushed++;
      } on Exception {
        break; // offline or server down — retry on next visit
      }
    }
    return pushed;
  }
}

/// Leaderboards, keyed by mode ('survival' or a daily id).
final arenaTopProvider = FutureProvider.autoDispose
    .family<List<ArenaScore>, String>((ref, mode) async {
  final config = await ref.watch(arenaConfigProvider.future);
  if (!config.enabled) return const [];
  return ref.watch(arenaApiProvider).top(mode: mode);
});

// Re-exported so the play screen has one import for repositories.
typedef ArenaGameRepository = GameRepository;
