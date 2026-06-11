import 'package:flutter/material.dart';

import '../module_placeholder.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Calendar',
      message: 'Events and scheduled tasks, side by side. '
          'The seasons will turn here soon.',
      icon: Icons.calendar_month_outlined,
      phase: 'Phase 3 · Calendar',
    );
  }
}
