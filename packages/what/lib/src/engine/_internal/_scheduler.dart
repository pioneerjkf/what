// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

abstract base class _SchedulerBase {
  bool _isScheduled = false;

  late final void Function() _taskHandler = _onTask;

  void _ensureScheduled() {
    if (_isScheduled) return;
    _isScheduled = true;
    scheduleMicrotask(_taskHandler);
  }

  @mustCallSuper
  void _onTask() {
    _isScheduled = false;
  }
}

/// Central asynchronous microtask scheduler coordinating batch execution passes.
///
/// ### Mixin Execution Order (Call-Stack Unwinding)
/// Due to Dart's mixin linearization and `super._onTask()` invocation wrapped in `try/finally`,
/// each stage is guaranteed to flush its pending queue even if a preceding stage throws an uncaught error:
/// 1. [_SchedulerBase] resets the scheduling flag `_isScheduled = false`.
/// 2. [_CoalescedSchedulerMixin] flushes trailing coalesced pulses in the DAG first.
/// 3. [_EagerSchedulerMixin] pre-emptively switches and allocates eager nodes next.
/// 4. [_TerminalSchedulerMixin] flushes active scheduled terminals.
/// 5. [_GracefulSchedulerMixin] executes deactivation cleanups LAST.
///
/// **Why Graceful Deactivation MUST run last:**
/// Active effects running in the current tick may still observe or depend on resources
/// whose subscribers dropped to zero during this epoch. Executing effects first ensures
/// that resources remain valid throughout effect evaluations, and are only gracefully
/// deactivated/disposed after all scheduled side-effects have completed.
base class _Scheduler extends _SchedulerBase
    with _CoalescedSchedulerMixin, _EagerSchedulerMixin, _TerminalSchedulerMixin, _GracefulSchedulerMixin {
  _Scheduler._();
  static final _Scheduler instance = _Scheduler._();
}

abstract base class _CoalescedSchedulable implements _Lifecycle {
  void _performCoalesce();
}

base mixin _CoalescedSchedulerMixin on _SchedulerBase {
  Set<_CoalescedSchedulable> _coalescedSet = <_CoalescedSchedulable>{};
  Set<_CoalescedSchedulable> _coalescedSwapSet = <_CoalescedSchedulable>{};

  bool _scheduleCoalesced(_CoalescedSchedulable target) {
    if (_coalescedSet.add(target)) {
      _ensureScheduled();
      return true;
    }
    return false;
  }

  bool _cancelCoalesced(_CoalescedSchedulable target) {
    return _coalescedSet.remove(target);
  }

  @mustCallSuper
  @override
  void _onTask() {
    try {
      super._onTask();
    } finally {
      if (_coalescedSet.isNotEmpty) {
        final processing = _coalescedSet;
        _coalescedSet = _coalescedSwapSet;
        _coalescedSwapSet = processing;

        try {
          for (final target in processing) {
            if (!target._lifecycle.isActive) continue;
            try {
              target._performCoalesce();
            } catch (error, stackTrace) {
              target._handleUncaughtError(error, stackTrace);
            }
          }
        } finally {
          processing.clear();
        }
      }
    }
  }
}

abstract base class _EagerSchedulable implements _Lifecycle {
  void _performScheduledEager();
}

base mixin _EagerSchedulerMixin on _SchedulerBase {
  Set<_EagerSchedulable> _eagerSet = <_EagerSchedulable>{};
  Set<_EagerSchedulable> _eagerSwapSet = <_EagerSchedulable>{};

  bool _scheduleEager(_EagerSchedulable target) {
    if (_eagerSet.add(target)) {
      _ensureScheduled();
      return true;
    }
    return false;
  }

  bool _cancelEager(_EagerSchedulable target) {
    return _eagerSet.remove(target);
  }

  @mustCallSuper
  @override
  void _onTask() {
    try {
      super._onTask();
    } finally {
      if (_eagerSet.isNotEmpty) {
        final processing = _eagerSet;
        _eagerSet = _eagerSwapSet;
        _eagerSwapSet = processing;

        try {
          for (final target in processing) {
            if (!target._lifecycle.isActive) continue;
            try {
              target._performScheduledEager();
            } catch (error, stackTrace) {
              target._handleUncaughtError(error, stackTrace);
            }
          }
        } finally {
          processing.clear();
        }
      }
    }
  }
}

abstract base class _TerminalSchedulable implements _Lifecycle {
  void _performScheduled();
}

base mixin _TerminalSchedulerMixin on _SchedulerBase {
  Set<_TerminalSchedulable> _terminalSet = <_TerminalSchedulable>{};
  Set<_TerminalSchedulable> _terminalSwapSet = <_TerminalSchedulable>{};

  bool _scheduleTerminal(_TerminalSchedulable target) {
    if (_terminalSet.add(target)) {
      _ensureScheduled();
      return true;
    }
    return false;
  }

  bool _cancelTerminal(_TerminalSchedulable target) {
    return _terminalSet.remove(target);
  }

  @mustCallSuper
  @override
  void _onTask() {
    try {
      super._onTask();
    } finally {
      if (_terminalSet.isNotEmpty) {
        final processing = _terminalSet;
        _terminalSet = _terminalSwapSet;
        _terminalSwapSet = processing;

        try {
          for (final target in processing) {
            if (!target._lifecycle.isActive) continue;
            try {
              target._performScheduled();
            } catch (error, stackTrace) {
              target._handleUncaughtError(error, stackTrace);
            }
          }
        } finally {
          processing.clear();
        }
      }
    }
  }
}

base mixin _GracefulSchedulerMixin on _SchedulerBase {
  Set<_MicrotaskGraceHandle> _pendingGraceHandles = <_MicrotaskGraceHandle>{};
  Set<_MicrotaskGraceHandle> _swapGraceHandles = <_MicrotaskGraceHandle>{};

  bool _scheduleGraceHandle(_MicrotaskGraceHandle handle) {
    if (_pendingGraceHandles.add(handle)) {
      _ensureScheduled();
      return true;
    }
    return false;
  }

  bool _cancelGraceHandle(_MicrotaskGraceHandle handle) {
    return _pendingGraceHandles.remove(handle);
  }

  @mustCallSuper
  @override
  void _onTask() {
    try {
      super._onTask();
    } finally {
      if (_pendingGraceHandles.isNotEmpty) {
        final processing = _pendingGraceHandles;
        _pendingGraceHandles = _swapGraceHandles;
        _swapGraceHandles = processing;

        try {
          for (final handle in processing) {
            try {
              handle._onExpired();
            } catch (error, stackTrace) {
              handle.node._handleUncaughtError(error, stackTrace);
            }
          }
        } finally {
          processing.clear();
        }
      }
    }
  }
}
