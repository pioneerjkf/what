// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// Push Scope & 2-Phase Drain Engine
// =============================================================================

/// Internal 2-Phase transaction scope manager for end-of-push synchronous flushes.
///
/// Collects causal [_PushOrigin] mutations and resulting [_RawTerminal] invalidations,
/// executing DFS dirty propagation (Phase 1) followed by synchronous batch
/// notification flushes (Phase 2). Reentrant mutations are flattened via a trampoline loop.
abstract final class _PushScope {
  static _PushOrigin? _pushOriginHead;
  static _PushOrigin? _pushOriginTail;

  static _RawTerminal? _flushTerminalHead;
  static _RawTerminal? _flushTerminalTail;

  static bool _drainLock = false;

  /// Queues [origin] as a mutation cause in the active pushing scope.
  @pragma('vm:prefer-inline')
  static void queueOrigin(_PushOrigin origin) {
    if (origin._isPushQueued) return;
    origin._isPushQueued = true;
    origin._nextPushOrigin = null;

    if (_pushOriginTail == null) {
      _pushOriginHead = origin;
      _pushOriginTail = origin;
    } else {
      _pushOriginTail!._nextPushOrigin = origin;
      _pushOriginTail = origin;
    }

    if (!_drainLock) {
      _drain();
    }
  }

  /// Queues [terminal] as an invalidation effect in the active pushing scope.
  @pragma('vm:prefer-inline')
  static void queueTerminal(_RawTerminal terminal) {
    if (terminal._isPushQueued) return;
    terminal._isPushQueued = true;
    terminal._nextFlushTerminal = null;

    if (_flushTerminalTail == null) {
      _flushTerminalHead = terminal;
      _flushTerminalTail = terminal;
    } else {
      _flushTerminalTail!._nextFlushTerminal = terminal;
      _flushTerminalTail = terminal;
    }

    if (!_drainLock) {
      _drain();
    }
  }

  /// Purges any pending origin and terminal queues, resetting intrusive flags.
  ///
  /// Invoked when a transaction or drain phase aborts due to an unhandled exception,
  /// ensuring fault isolation, preventing zombie node flags, and avoiding dirty state leaks.
  @pragma('vm:prefer-inline')
  static void _purgeQueues() {
    var e = _pushOriginHead;
    while (e != null) {
      final next = e._nextPushOrigin;
      e._nextPushOrigin = null;
      e._isPushQueued = false;
      e = next;
    }
    _pushOriginHead = null;
    _pushOriginTail = null;

    var t = _flushTerminalHead;
    while (t != null) {
      final next = t._nextFlushTerminal;
      t._nextFlushTerminal = null;
      t._isPushQueued = false;
      t = next;
    }
    _flushTerminalHead = null;
    _flushTerminalTail = null;
  }

  static void _drain() {
    _drainLock = true;
    var completed = false;
    try {
      while (_pushOriginHead != null || (!_BatchScope._batchLock && _flushTerminalHead != null)) {
        // Phase 1: Dirty Propagation (Causes) - executed eagerly even during batches.
        while (_pushOriginHead != null) {
          final origin = _pushOriginHead!;
          _pushOriginHead = origin._nextPushOrigin;
          if (_pushOriginHead == null) {
            _pushOriginTail = null;
          }
          origin._nextPushOrigin = null;
          origin._isPushQueued = false;

          try {
            origin._propagateDirty();
          } catch (error, stackTrace) {
            origin._handleUncaughtError(error, stackTrace);
          }
        }

        // Phase 2: Synchronous Terminal Flush (Effects) - deferred until batch scope completes.
        if (!_BatchScope._batchLock) {
          while (_flushTerminalHead != null) {
            final terminal = _flushTerminalHead!;
            _flushTerminalHead = terminal._nextFlushTerminal;
            if (_flushTerminalHead == null) {
              _flushTerminalTail = null;
            }
            terminal._nextFlushTerminal = null;
            terminal._isPushQueued = false;

            try {
              terminal._invalidateInScope();
            } catch (error, stackTrace) {
              terminal._handleUncaughtError(error, stackTrace);
            }

            // If a flush callback queued new origins (Reentrancy),
            // yield immediately to Phase 1 so new dirty states propagate
            // before flushing subsequent terminals.
            if (_pushOriginHead != null) {
              break;
            }
          }
        }
      }
      completed = true;
    } finally {
      // If drain terminated abnormally due to an escaping exception,
      // purge all remaining queues unconditionally (even if inside a batch)
      // to isolate faults and prevent zombie node flags (_isPushQueued).
      //
      // In a normal completion, if not in batchLock, both heads are already null.
      // If in batchLock, _flushTerminalHead is preserved for the outermost batch completion.
      if (!completed) {
        _purgeQueues();
      }
      _drainLock = false;
    }
  }
}
