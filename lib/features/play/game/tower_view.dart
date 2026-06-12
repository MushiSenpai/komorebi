import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';
import 'pieces.dart';
import 'tower_world.dart';

/// Renders and ticks a [TowerWorld]: keyboard input, smooth camera, and a
/// hand-drawn look (island, sea, sky) via CustomPainter — no game engine.
class TowerView extends StatefulWidget {
  const TowerView({super.key, required this.world});

  final TowerWorld world;

  @override
  State<TowerView> createState() => _TowerViewState();
}

class _TowerViewState extends State<TowerView> {
  // The simulation runs on a plain event-loop timer and repaints through
  // the painter's `repaint` listenable — no setState per frame. (A 60fps
  // setState storm from a frame-callback Ticker starves the Linux GTK
  // embedder's presenter on some Xorg setups: frames were produced but
  // almost never shown.)
  static const _step = Duration(milliseconds: 33);
  Timer? _timer;
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  double _cameraY = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _frame.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tick() {
    const dt = 0.033;
    widget.world.update(dt);
    _cameraY += (widget.world.cameraTargetY - _cameraY) * min(1, dt * 3);
    _frame.value++;
  }

  void _onKeyEvent(KeyEvent event) {
    final world = widget.world;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    world.moveLeft = pressed.contains(LogicalKeyboardKey.arrowLeft) ||
        pressed.contains(LogicalKeyboardKey.keyA);
    world.moveRight = pressed.contains(LogicalKeyboardKey.arrowRight) ||
        pressed.contains(LogicalKeyboardKey.keyD);
    world.softDrop = pressed.contains(LogicalKeyboardKey.arrowDown) ||
        pressed.contains(LogicalKeyboardKey.keyS);
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        world.rotateActive();
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        world.hardDrop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TowerPainter(
            world: widget.world,
            cameraY: () => _cameraY,
            sky: tokens.paper,
            sea: tokens.coolAccent,
            island: tokens.accent,
            repaint: _frame,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TowerPainter extends CustomPainter {
  _TowerPainter({
    required this.world,
    required this.cameraY,
    required this.sky,
    required this.sea,
    required this.island,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final TowerWorld world;
  final double Function() cameraY;
  final Color sky;
  final Color sea;
  final Color island;

  static const zoom = 44.0; // pixels per metre

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);

    canvas.save();
    // World → screen: centre x, camera-followed y.
    canvas.translate(size.width / 2, size.height / 2 - cameraY() * zoom);
    canvas.scale(zoom);

    // Sea.
    final seaTop = TowerWorld.waterY;
    canvas.drawRect(
      Rect.fromLTRB(-size.width / zoom, seaTop, size.width / zoom,
          seaTop + size.height / zoom),
      Paint()..color = sea.withValues(alpha: 0.5),
    );

    // Island: a soft grassy slab with a darker base.
    final islandRect = Rect.fromCenter(
      center: const Offset(0, TowerWorld.islandTopY + 0.5),
      width: TowerWorld.islandHalfWidth * 2,
      height: 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          islandRect.inflate(0.06), const Radius.circular(0.2)),
      Paint()..color = island.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(islandRect, const Radius.circular(0.16)),
      Paint()..color = island,
    );

    // Pieces.
    for (final piece in [...world.pieces, ?world.active]) {
      _paintPiece(canvas, piece);
    }
    canvas.restore();
  }

  void _paintPiece(Canvas canvas, TowerPiece piece) {
    final body = piece.body;
    canvas.save();
    canvas.translate(body.position.x, body.position.y);
    canvas.rotate(body.angle);
    final fill = Paint()..color = piece.spec.color;
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    for (final (cx, cy) in piece.spec.cells) {
      final rect = Rect.fromCenter(
        center:
            Offset(cx * PieceSpec.cellSize, cy * PieceSpec.cellSize),
        width: PieceSpec.cellSize - 0.04,
        height: PieceSpec.cellSize - 0.04,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, const Radius.circular(0.08));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, edge);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TowerPainter oldDelegate) => true;
}
