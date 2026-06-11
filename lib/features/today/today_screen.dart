import 'package:flutter/material.dart';

import '../module_placeholder.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Today',
      message: 'A quiet morning in the meadow. Your tasks for today — '
          'and the overdue stragglers — will gather here.',
      icon: Icons.wb_sunny_outlined,
      phase: 'Phase 1 · Tasks',
    );
  }
}
