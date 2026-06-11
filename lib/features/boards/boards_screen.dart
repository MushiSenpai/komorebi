import 'package:flutter/material.dart';

import '../module_placeholder.dart';

class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Boards',
      message: 'Each project gets its own kanban board. '
          'Cards will drift between columns like leaves on a stream.',
      icon: Icons.view_kanban_outlined,
      phase: 'Phase 2 · Kanban',
    );
  }
}
