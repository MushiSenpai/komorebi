import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';

import 'pieces.dart';

/// One piece in the world: its body plus rendering/scoring metadata.
class TowerPiece {
  TowerPiece(this.spec, this.body);

  final PieceSpec spec;
  final Body body;
  var landed = false;

  /// Highest (lowest-y) point among this piece's cells, world metres.
  double get topY {
    var top = double.infinity;
    const half = PieceSpec.cellSize / 2;
    for (final (cx, cy) in spec.cells) {
      final world = body.worldPoint(
          Vector2(cx * PieceSpec.cellSize, cy * PieceSpec.cellSize));
      top = min(top, world.y - half);
    }
    return top;
  }
}

class _LandingListener extends ContactListener {
  @override
  void beginContact(Contact contact) {
    for (final data in [
      contact.fixtureA.body.userData,
      contact.fixtureB.body.userData,
    ]) {
      if (data is TowerPiece) data.landed = true;
    }
  }
}

/// Tsumiki Towers survival simulation (SPEC §5.6), engine-free: pure forge2d
/// physics stepped by a widget ticker and drawn by a CustomPainter.
///
/// Y grows downward; the island top sits at y = 0 and the waterline at
/// y = [waterY]. The tower grows toward negative y.
class TowerWorld {
  TowerWorld({int? seed}) : _rng = Random(seed) {
    world = World(Vector2(0, 10));
    world.setContactListener(_LandingListener());
    _createIsland();
    spawnPiece();
  }

  final Random _rng;
  late final World world;

  // HUD state.
  final hearts = ValueNotifier<int>(3);
  final heightBlocks = ValueNotifier<int>(0);
  final piecesPlaced = ValueNotifier<int>(0);
  final gameOver = ValueNotifier<bool>(false);

  static const islandHalfWidth = 2.4;
  static const islandTopY = 0.0;
  static const waterY = 6.0;
  static const spawnHeight = 8.0;

  final startedAt = DateTime.now();
  final pieces = <TowerPiece>[];
  TowerPiece? active;
  double towerTopY = islandTopY;
  var _settleTimer = 0.0;
  var _elapsed = 0.0;

  // Pressed-state controls.
  var moveLeft = false;
  var moveRight = false;
  var softDrop = false;

  /// Camera target: keeps the action centred as the tower grows.
  double get cameraTargetY => min(1.5, towerTopY + 3.0);

  int get durationSeconds => DateTime.now().difference(startedAt).inSeconds;

  void _createIsland() {
    final body = world.createBody(BodyDef(
      type: BodyType.static,
      position: Vector2(0, islandTopY + 0.5),
    ));
    body.createFixture(FixtureDef(
      PolygonShape()..setAsBoxXY(islandHalfWidth, 0.5),
      friction: 0.9,
    ));
  }

  @visibleForTesting
  void spawnPiece() {
    if (gameOver.value) return;
    final spec = PieceSpec.random(_rng);
    final body = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: Vector2(0, min(towerTopY, islandTopY) - spawnHeight),
      fixedRotation: false,
    ));
    const half = PieceSpec.cellSize / 2;
    for (final (cx, cy) in spec.cells) {
      body.createFixture(FixtureDef(
        PolygonShape()
          ..setAsBox(half, half,
              Vector2(cx * PieceSpec.cellSize, cy * PieceSpec.cellSize), 0),
        density: 1.2,
        friction: 0.85,
        restitution: 0.02,
      ));
    }
    final piece = TowerPiece(spec, body);
    body.userData = piece;
    active = piece;
  }

  void rotateActive() {
    final piece = active;
    if (piece == null || gameOver.value) return;
    piece.body.setTransform(piece.body.position, piece.body.angle + pi / 2);
    piece.body.angularVelocity = 0;
  }

  void hardDrop() {
    active?.body.linearVelocity = Vector2(0, 14);
  }

  /// Advances the simulation by [dt] seconds.
  void update(double dt) {
    if (gameOver.value) return;
    _elapsed += dt;

    final piece = active;
    if (piece != null) {
      if (!piece.landed) {
        final vx = moveLeft == moveRight ? 0.0 : (moveLeft ? -3.5 : 3.5);
        final vy =
            max(piece.body.linearVelocity.y, softDrop ? 7.0 : 2.2);
        piece.body.linearVelocity = Vector2(vx, vy);
        // Gentle wind once the tower passes ten blocks (SPEC §5.6).
        if (heightToBlocks(islandTopY - towerTopY) >= 10) {
          piece.body
              .applyForce(Vector2(sin(_elapsed * 1.4) * 1.4, 0));
        }
      } else {
        _settleTimer += dt;
        if (_settleTimer > 0.8) {
          _settleTimer = 0;
          pieces.add(piece);
          piecesPlaced.value++;
          active = null;
          spawnPiece();
        }
      }
    }

    world.stepDt(dt > 1 / 30 ? 1 / 30 : dt);
    _drownAndMeasure();
  }

  void _drownAndMeasure() {
    final drowned = <TowerPiece>[
      for (final p in [...pieces, ?active])
        if (p.body.position.y > waterY) p,
    ];
    for (final piece in drowned) {
      final wasActive = piece == active;
      pieces.remove(piece);
      world.destroyBody(piece.body);
      if (wasActive) active = null;
      hearts.value = max(0, hearts.value - 1);
      if (hearts.value == 0) {
        gameOver.value = true;
        return;
      }
      if (wasActive) spawnPiece();
    }

    var top = islandTopY;
    for (final piece in pieces) {
      top = min(top, piece.topY);
    }
    towerTopY = top;
    heightBlocks.value =
        max(heightBlocks.value, heightToBlocks(islandTopY - top));
  }
}
