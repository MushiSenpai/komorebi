import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../features/focus/pomodoro_controller.dart';
import 'router.dart';

/// Adaptive app shell: navigation rail on wide layouts (desktop),
/// bottom navigation bar on narrow ones (mobile). SPEC §6.
class KomorebiShell extends ConsumerWidget {
  const KomorebiShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _railBreakpoint = 720.0;

  void _goBranch(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  /// Floating countdown chip while a pomodoro runs and another tab is open
  /// (SPEC §5.5: the timer is never lost).
  Widget _withTimerChip(BuildContext context, WidgetRef ref, Widget body) {
    final pomo = ref.watch(pomodoroProvider);
    final focusIndex = KomorebiDestination.values
        .indexOf(KomorebiDestination.focus);
    if (!pomo.running || shell.currentIndex == focusIndex) return body;

    final tokens = context.komorebi;
    final remaining = pomo.remaining(DateTime.now());
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final mm = clamped.inMinutes.toString().padLeft(2, '0');
    final ss = (clamped.inSeconds % 60).toString().padLeft(2, '0');

    return Stack(
      children: [
        body,
        Positioned(
          right: 16,
          bottom: 16,
          child: Material(
            color: tokens.ink,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _goBranch(focusIndex),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pomo.phase == PomodoroPhase.work
                          ? Icons.timer
                          : Icons.free_breakfast,
                      size: 16,
                      color: tokens.paper,
                    ),
                    const SizedBox(width: 6),
                    Text('$mm:$ss',
                        style: TextStyle(color: tokens.paper, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= _railBreakpoint;
    final destinations = KomorebiDestination.values;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _goBranch,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 12),
                child: _KomorebiMark(),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.push('/settings'),
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _withTimerChip(context, ref, shell)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _KomorebiMark(),
            SizedBox(width: 8),
            Text('Komorebi'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _withTimerChip(context, ref, shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Tiny leaf-and-sun mark standing in for the future hand-drawn logo.
class _KomorebiMark extends StatelessWidget {
  const _KomorebiMark();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Icon(Icons.spa, color: color, size: 28);
  }
}
