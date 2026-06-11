import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repos/pomodoro_repository.dart';
import '../../services/notifications.dart';

enum PomodoroPhase { idle, work, shortBreak, longBreak }

/// Immutable timer state; `endsAt` drives the countdown so the timer stays
/// correct across rebuilds and brief suspends.
class PomodoroState {
  const PomodoroState({
    this.phase = PomodoroPhase.idle,
    this.startedAt,
    this.endsAt,
    this.taskId,
    this.taskTitle,
    this.completedWork = 0,
    this.breakSuggested = false,
  });

  final PomodoroPhase phase;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final String? taskId;
  final String? taskTitle;

  /// Completed work sessions this streak (drives the long-break cadence).
  final int completedWork;

  /// True right after a work session ends — the UI offers the break game.
  final bool breakSuggested;

  bool get running => phase != PomodoroPhase.idle;

  Duration remaining(DateTime now) =>
      endsAt == null ? Duration.zero : endsAt!.difference(now);

  PomodoroState copyWith({
    PomodoroPhase? phase,
    DateTime? startedAt,
    DateTime? endsAt,
    String? taskId,
    String? taskTitle,
    int? completedWork,
    bool? breakSuggested,
    bool clearTask = false,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      taskId: clearTask ? null : taskId ?? this.taskId,
      taskTitle: clearTask ? null : taskTitle ?? this.taskTitle,
      completedWork: completedWork ?? this.completedWork,
      breakSuggested: breakSuggested ?? this.breakSuggested,
    );
  }
}

final pomodoroRepositoryProvider = Provider<PomodoroRepository>(
  (ref) => PomodoroRepository(ref.watch(databaseProvider)),
);

final pomodoroProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);

/// Drives the work/break cycle (SPEC §5.5). A 1-second timer re-publishes
/// state while running so the UI ticks; phase changes log sessions and fire
/// a local notification.
class PomodoroController extends Notifier<PomodoroState> {
  // ignore: prefer_initializing_formals — initializing formals can't be private
  PomodoroController({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;
  Timer? _ticker;
  PomodoroConfig _config = PomodoroRepository.defaults;

  DateTime get _now => (_clock ?? DateTime.now)();

  @override
  PomodoroState build() {
    ref.onDispose(() => _ticker?.cancel());
    Future(() async {
      _config = await ref.read(pomodoroRepositoryProvider).loadConfig();
    }).ignore();
    return const PomodoroState();
  }

  PomodoroConfig get config => _config;

  Future<void> reloadConfig() async {
    _config = await ref.read(pomodoroRepositoryProvider).loadConfig();
    state = state.copyWith(); // re-publish for settings UI
  }

  /// Sets (or clears) the task the next focus session is dedicated to.
  void linkTask({String? taskId, String? taskTitle}) {
    state = taskId == null
        ? state.copyWith(clearTask: true)
        : state.copyWith(taskId: taskId, taskTitle: taskTitle);
  }

  void startWork({String? taskId, String? taskTitle}) {
    final now = _now;
    state = PomodoroState(
      phase: PomodoroPhase.work,
      startedAt: now,
      endsAt: now.add(_config.work),
      taskId: taskId,
      taskTitle: taskTitle,
      completedWork: state.completedWork,
    );
    _startTicker();
  }

  /// Abandons the current phase. Work time spent still gets logged, marked
  /// incomplete — no guilt, but no lost minutes either.
  Future<void> stop() async {
    _ticker?.cancel();
    final current = state;
    if (current.phase == PomodoroPhase.work && current.startedAt != null) {
      await ref.read(pomodoroRepositoryProvider).logSession(
            taskId: current.taskId,
            kind: 'work',
            startedAt: current.startedAt!,
            endedAt: _now,
            completed: false,
          );
    }
    state = PomodoroState(completedWork: current.completedWork);
  }

  void skipBreak() {
    if (state.phase != PomodoroPhase.shortBreak &&
        state.phase != PomodoroPhase.longBreak) {
      return;
    }
    _ticker?.cancel();
    state = PomodoroState(
      completedWork: state.completedWork,
      taskId: state.taskId,
      taskTitle: state.taskTitle,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Visible for tests: advances phase when the clock passes endsAt.
  Future<void> tickNow() => _tick();

  Future<void> _tick() async {
    final current = state;
    final endsAt = current.endsAt;
    if (!current.running || endsAt == null) return;
    if (_now.isBefore(endsAt)) {
      state = current.copyWith(); // re-publish remaining time
      return;
    }

    final repo = ref.read(pomodoroRepositoryProvider);
    switch (current.phase) {
      case PomodoroPhase.work:
        await repo.logSession(
          taskId: current.taskId,
          kind: 'work',
          startedAt: current.startedAt!,
          endedAt: endsAt,
          completed: true,
        );
        final done = current.completedWork + 1;
        final long = done % _config.longEvery == 0;
        final breakLength = long ? _config.longBreak : _config.shortBreak;
        state = PomodoroState(
          phase: long ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
          startedAt: endsAt,
          endsAt: endsAt.add(breakLength),
          taskId: current.taskId,
          taskTitle: current.taskTitle,
          completedWork: done,
          breakSuggested: true,
        );
        Notifications.instance.show(
          'Focus complete',
          long
              ? 'Lovely work. Take a long break — the tower awaits.'
              : 'Take ${breakLength.inMinutes} gentle minutes.',
        );
      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        await repo.logSession(
          kind: 'break',
          startedAt: current.startedAt!,
          endedAt: endsAt,
          completed: true,
        );
        _ticker?.cancel();
        state = PomodoroState(
          completedWork: current.completedWork,
          taskId: current.taskId,
          taskTitle: current.taskTitle,
        );
        Notifications.instance
            .show('Break over', 'Ready for the next focus?');
      case PomodoroPhase.idle:
        break;
    }
  }
}
