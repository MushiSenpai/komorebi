import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repos/game_repository.dart';
import '../../design/tokens.dart';
import 'game/tower_view.dart';
import 'game/tower_world.dart';

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => GameRepository(ref.watch(databaseProvider)),
);

final topScoresProvider = StreamProvider<List<GameScore>>(
  (ref) => ref.watch(gameRepositoryProvider).watchTopScores(),
);

/// Tsumiki Towers (SPEC §5.6): physics tower stacking for real breaks.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  TowerWorld? _game;
  var _scoreSaved = false;

  void _start() {
    setState(() {
      _game = TowerWorld();
      _scoreSaved = false;
      _game!.gameOver.addListener(_onGameOver);
    });
  }

  Future<void> _onGameOver() async {
    final game = _game;
    if (game == null || !game.gameOver.value || _scoreSaved) return;
    _scoreSaved = true;
    await ref.read(gameRepositoryProvider).saveScore(
          score: game.heightBlocks.value,
          piecesPlaced: game.piecesPlaced.value,
          durationSeconds: game.durationSeconds,
        );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _game?.gameOver.removeListener(_onGameOver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      body: SafeArea(
        child: game == null ? _StartView(onStart: _start) : _gameView(game),
      ),
    );
  }

  Widget _gameView(TowerWorld game) {
    final tokens = context.komorebi;
    return Stack(
      children: [
        Positioned.fill(child: TowerView(world: game)),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: game.hearts,
                builder: (context, hearts, _) => Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(
                        i < hearts ? Icons.favorite : Icons.favorite_border,
                        color: tokens.warmAccent,
                        size: 20,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: game.heightBlocks,
                builder: (context, blocks, _) => Text(
                  '$blocks block${blocks == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Abandon run',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _game = null),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: _TouchControls(game: game),
        ),
        ValueListenableBuilder(
          valueListenable: game.gameOver,
          builder: (context, over, _) => over
              ? Positioned.fill(
                  child: ColoredBox(
                    color: tokens.ink.withValues(alpha: 0.55),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('The tower rests',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 8),
                              Text(
                                '${game.heightBlocks.value} blocks · '
                                '${game.piecesPlaced.value} pieces',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton.icon(
                                    icon: const Icon(Icons.replay),
                                    label: const Text('Stack again'),
                                    onPressed: _start,
                                  ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _game = null),
                                    child: const Text('Done'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StartView extends ConsumerWidget {
  const _StartView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final scores = ref.watch(topScoresProvider).value ?? const <GameScore>[];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.castle_outlined, size: 56, color: tokens.accent),
            const SizedBox(height: 12),
            Text('Tsumiki Towers',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Stack falling blocks on a tiny island. Real physics, real '
              'wobbles — three splashes and the run is over.\n'
              '← → move · ↑ rotate · ↓ faster · space drop',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.inkSoft),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start stacking'),
                onPressed: onStart,
              ),
            ),
            if (scores.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Tallest towers',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final (i, score) in scores.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 24,
                          child: Text('${i + 1}.',
                              style: TextStyle(color: tokens.inkSoft))),
                      Expanded(
                        child: Text(
                            '${score.score} blocks · ${score.piecesPlaced} pieces'),
                      ),
                      Text(
                        DateFormat.MMMd().format(score.playedAt),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: tokens.inkSoft),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.game});

  final TowerWorld game;

  Widget _hold(IconData icon, void Function(bool) set) {
    return Listener(
      onPointerDown: (_) => set(true),
      onPointerUp: (_) => set(false),
      onPointerCancel: (_) => set(false),
      child: _round(icon),
    );
  }

  Widget _tap(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: _round(icon));
  }

  Widget _round(IconData icon) {
    return Builder(
      builder: (context) {
        final tokens = context.komorebi;
        return Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: tokens.paperRaised.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Icon(icon, color: tokens.ink),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _hold(Icons.chevron_left, (v) => game.moveLeft = v),
        _tap(Icons.rotate_right, game.rotateActive),
        _hold(Icons.keyboard_double_arrow_down, (v) => game.softDrop = v),
        _tap(Icons.vertical_align_bottom, game.hardDrop),
        _hold(Icons.chevron_right, (v) => game.moveRight = v),
      ],
    );
  }
}
