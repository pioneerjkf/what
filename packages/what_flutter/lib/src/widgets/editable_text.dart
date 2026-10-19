// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

// =============================================================================
// WhatTextEditingController: Bidirectional Zero-Jump Form Controller
// =============================================================================

/// A specialized [TextEditingController] bidirectionally bound to a [WhatController<String>]
/// with built-in cursor jumping immunity, CJK IME composition preservation, and re-entrancy loop guards.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                   WhatTextEditingController Flow                       │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │   [ Keyboard Typing (UI) ]              [ External State Change ]      │
/// │              │                                      │                  │
/// │              ▼                                      ▼                  │
/// │      TextEditingValue                     WhatController<String>       │
/// │              │                                      │                  │
/// │              ▼ [_isUpdatingFromUI = true]           ▼                  │
/// │       target.set(text)                     RawWhatTerminal             │
/// │              │                                      │                  │
/// │              ▼                                      ▼                  │
/// │    _onWhatChanged ignores!                _isUpdatingFromWhat = true   │
/// │    (0-jump, IME intact)                   Smart Selection Clamping     │
/// │                                                     │                  │
/// │                                                     ▼                  │
/// │                                            TextEditingValue (safe!)    │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Cursor Jumping Immunity**: When user types in the middle of text, What avoids
///    re-assigning `controller.value`, preventing Flutter's default reset to selection offset -1.
/// 2. **CJK IME Composition Protection**: Active composition ranges (`value.isComposingRangeValid`)
///    remain completely intact during typing.
/// 3. **Ping-Pong Re-entrancy Shield**: UI-initiated mutations and state-initiated mutations
///    are guarded by mutual exclusion flags, eliminating infinite feedback loops.
/// 4. **Smart Selection Clamping**: External state changes clamp prior selection offsets
///    within `[0, newText.length]` without crashing or blowing away the cursor.
/// 5. **Zero-Leak Lifecycle Coupling**: When instantiated and bound to a [WhatWidget] or managed store,
///    the controller synchronizes with the reactive target and safely disposes via standard [TextEditingController.dispose].
///
/// **Warning (Anti-Pattern Prevention):**
/// - Do NOT instantiate a [WhatTextEditingController] directly inside `build` without caching,
///   as this re-allocates text controllers on every frame and breaks user text input.
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Re-creates WhatTextEditingController per frame in build
/// Widget build(BuildContext context) {
///   final textController = WhatTextEditingController(query);
///   return TextField(controller: textController);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Cache in a field or store
/// class SearchBarWidget extends StatelessWidget {
///   SearchBarWidget({super.key});
///   final query = WhatController('');
///   late final textController = query.bindTextController();
/// }
/// ```
///
/// ## Examples
/// ```dart
/// class SearchBarWidget extends StatelessWidget {
///   SearchBarWidget({super.key});
///
///   final query = WhatController('');
///   late final textController = WhatTextEditingController(query);
///   // or: late final textController = query.bindTextController();
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       controller: textController,
///       decoration: const InputDecoration(hintText: 'Search...'),
///     );
///   }
/// }
/// ```
final class WhatTextEditingController extends TextEditingController {
  /// Creates a [WhatTextEditingController] bidirectionally bound to [target].
  ///
  /// * [target]: The reactive producer controller managing the underlying string state.
  /// * [text]: Optional initial text. If omitted, initializes from `target.data` (if available).
  ///   When [target] is in an uninitialized/Empty state (e.g. [WhatController.late]), the controller defaults
  ///   to `''` in the UI without polluting or forcing state transitions on [target] until user input occurs.
  /// * [clearOnEmpty]: Whether to reset [text] to empty when `target.empty()` is invoked. Defaults to `true`.
  ///   If `false`, existing text is preserved when [target] transitions to the Empty state.
  /// * [onError]: Optional error boundary callback for uncaught terminal exceptions.
  ///
  /// **Requires:**
  /// * [target] must be a non-null [WhatController<String>].
  ///
  /// **Ensures:**
  /// * Returns a bidirectionally synchronized [WhatTextEditingController] protecting cursor offset and IME state.
  WhatTextEditingController(
    WhatController<String> target, {
    String? text,
    this.clearOnEmpty = true,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : _target = target,
        super(text: text ?? (target.hasData ? target.data : '')) {
    if (text != null && (!target.hasData || target.data != text)) {
      target.set(text);
    }

    _terminal = RawWhatTerminal<String>(
      target.what,
      onInvalidated: _onWhatChanged,
      onUncaughtError: onError,
    );
    _terminal.activate();

    addListener(_onControllerChanged);
  }

  final WhatController<String> _target;
  late final RawWhatTerminal<String> _terminal;

  /// Whether to clear the text field when `target.empty()` is called.
  final bool clearOnEmpty;

  bool _isUpdatingFromUI = false;
  bool _isUpdatingFromWhat = false;
  bool _isDisposed = false;

  /// The underlying [WhatController<String>] target.
  WhatController<String> get target => _target;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  void _onControllerChanged() {
    if (_isDisposed) return;
    if (_isUpdatingFromWhat) return;

    final currentText = text;
    if (_target.hasData && _target.data == currentText) {
      return;
    }

    _isUpdatingFromUI = true;
    try {
      _target.set(currentText);
    } finally {
      _isUpdatingFromUI = false;
    }
  }

  void _onWhatChanged() {
    if (_isDisposed) return;
    if (_isUpdatingFromUI) return;

    if (!_target.hasData) {
      if (clearOnEmpty && text.isNotEmpty) {
        _isUpdatingFromWhat = true;
        try {
          _updateTextPreservingSelection('');
        } finally {
          _isUpdatingFromWhat = false;
        }
      }
      return;
    }

    final nextText = _target.data;
    if (text == nextText) {
      // Content identical: NEVER touch value, preserving cursor & IME!
      return;
    }

    _isUpdatingFromWhat = true;
    try {
      _updateTextPreservingSelection(nextText);
    } finally {
      _isUpdatingFromWhat = false;
    }
  }

  @pragma('vm:prefer-inline')
  void _updateTextPreservingSelection(String nextText) {
    final currentSelection = selection;
    final TextSelection safeSelection;
    if (currentSelection.isValid) {
      final base = currentSelection.baseOffset.clamp(0, nextText.length);
      final extent = currentSelection.extentOffset.clamp(0, nextText.length);
      safeSelection = currentSelection.copyWith(
        baseOffset: base,
        extentOffset: extent,
      );
    } else {
      safeSelection = TextSelection.collapsed(offset: nextText.length);
    }

    value = TextEditingValue(
      text: nextText,
      selection: safeSelection,
      composing: TextRange.empty,
    );
  }

  @mustCallSuper
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    removeListener(_onControllerChanged);
    _terminal.deactivate();
    super.dispose();
  }

  @override
  String toString() =>
      '${describeIdentity(this)}(target: $_target, text: "$text", isDisposed: $_isDisposed)';
}

/// Extension on [WhatController<String>] providing convenient creation of a [WhatTextEditingController].
extension WhatStringControllerBindingExtension on WhatController<String> {
  /// Creates a [WhatTextEditingController] bidirectionally bound to this [WhatController<String>].
  ///
  /// * [text]: Optional initial text. If omitted, initializes from this controller's data.
  /// * [clearOnEmpty]: Whether to reset text to empty when this controller is emptied.
  /// * [onError]: Optional error boundary callback for uncaught exceptions.
  ///
  /// **Requires:**
  /// * This controller must be a valid, active [WhatController<String>].
  ///
  /// **Ensures:**
  /// * Returns a [WhatTextEditingController] bound to this [WhatController<String>].
  ///
  /// ## Examples
  /// ```dart
  /// late final textController = queryController.bindTextController();
  /// ```
  @pragma('vm:prefer-inline')
  WhatTextEditingController bindTextController({
    String? text,
    bool clearOnEmpty = true,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) =>
      WhatTextEditingController(
        this,
        text: text,
        clearOnEmpty: clearOnEmpty,
        onError: onError,
      );
}
