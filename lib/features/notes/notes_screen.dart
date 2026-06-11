import 'package:flutter/material.dart';

import '../module_placeholder.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Notes',
      message: 'Markdown notes with [[wiki-links]] and backlinks. '
          'A library in the forest, every book connected.',
      icon: Icons.menu_book_outlined,
      phase: 'Phase 4 · Notes',
    );
  }
}
