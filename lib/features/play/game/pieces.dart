import 'dart:math';
import 'dart:ui';

/// Tetromino definitions for Tsumiki Towers (SPEC §5.6).
///
/// Each piece is four cells; offsets are in cell units around the piece
/// origin. Physics bodies get one square fixture per cell.
class PieceSpec {
  const PieceSpec(this.name, this.cells, this.color);

  final String name;
  final List<(int, int)> cells;
  final Color color;

  /// World size of one cell, metres.
  static const cellSize = 0.6;

  static const all = [
    PieceSpec('I', [(-2, 0), (-1, 0), (0, 0), (1, 0)], Color(0xFF9DBBC7)),
    PieceSpec('O', [(0, 0), (1, 0), (0, 1), (1, 1)], Color(0xFFE8A84C)),
    PieceSpec('T', [(-1, 0), (0, 0), (1, 0), (0, -1)], Color(0xFFB5C9A5)),
    PieceSpec('L', [(-1, 0), (0, 0), (1, 0), (1, -1)], Color(0xFFCB7B5C)),
    PieceSpec('J', [(-1, -1), (-1, 0), (0, 0), (1, 0)], Color(0xFF7C9A6D)),
    PieceSpec('S', [(-1, 0), (0, 0), (0, -1), (1, -1)], Color(0xFFE3B7B1)),
    PieceSpec('Z', [(-1, -1), (0, -1), (0, 0), (1, 0)], Color(0xFFC3514E)),
  ];

  static PieceSpec random(Random rng) => all[rng.nextInt(all.length)];
}

/// Converts a stable tower height in metres above the island surface into
/// whole blocks — the survival score (SPEC §5.6).
int heightToBlocks(double metres) =>
    metres <= 0 ? 0 : (metres / PieceSpec.cellSize).floor();
