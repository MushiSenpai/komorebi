import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/boards/boards_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/play/play_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

/// The six module destinations shown in the rail / bottom bar (SPEC §6).
enum KomorebiDestination {
  today('/today', 'Today', Icons.wb_sunny_outlined, Icons.wb_sunny),
  boards('/boards', 'Boards', Icons.view_kanban_outlined, Icons.view_kanban),
  calendar('/calendar', 'Calendar', Icons.calendar_month_outlined,
      Icons.calendar_month),
  notes('/notes', 'Notes', Icons.menu_book_outlined, Icons.menu_book),
  focus('/focus', 'Focus', Icons.timer_outlined, Icons.timer),
  play('/play', 'Play', Icons.castle_outlined, Icons.castle);

  const KomorebiDestination(this.path, this.label, this.icon, this.activeIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Builds a fresh router per app instance (a global router would leak
/// navigation state across widget tests and hot restarts).
GoRouter buildRouter() => GoRouter(
  initialLocation: KomorebiDestination.today.path,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => KomorebiShell(shell: shell),
      branches: [
        _branch(KomorebiDestination.today, const TodayScreen()),
        _branch(KomorebiDestination.boards, const BoardsScreen()),
        _branch(KomorebiDestination.calendar, const CalendarScreen()),
        _branch(KomorebiDestination.notes, const NotesScreen()),
        _branch(KomorebiDestination.focus, const FocusScreen()),
        _branch(KomorebiDestination.play, const PlayScreen()),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

StatefulShellBranch _branch(KomorebiDestination dest, Widget screen) {
  return StatefulShellBranch(
    routes: [
      GoRoute(path: dest.path, builder: (context, state) => screen),
    ],
  );
}
