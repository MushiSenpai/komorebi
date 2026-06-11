import 'package:flutter/material.dart';

import '../module_placeholder.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Tsumiki Towers',
      message: 'Stack tetromino blocks on a tiny island; real physics, '
          'real wobbles. Build tall, take breaks, beat your friends.',
      icon: Icons.castle_outlined,
      phase: 'Phase 6 · Game',
    );
  }
}
