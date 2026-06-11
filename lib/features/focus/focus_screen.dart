import 'package:flutter/material.dart';

import '../module_placeholder.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Focus',
      message: 'Pomodoro sessions linked to your tasks, with gentle stats. '
          'Twenty-five minutes of sunlight at a time.',
      icon: Icons.timer_outlined,
      phase: 'Phase 5 · Pomodoro',
    );
  }
}
