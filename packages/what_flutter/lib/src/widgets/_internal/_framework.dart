// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// Reactive Terminal Element Mixins
// =============================================================================

/// Foundational mixin managing the unified lifecycle of any reactive [RawTerminal].
mixin _ReactiveTerminalElementMixin<T extends RawTerminal> on ComponentElement {
  /// The reactive terminal sink hosted by this element.
  T get terminal;

  @visibleForTesting
  void handleTerminalUncaughtError(Object error, StackTrace stackTrace) {
    _handleTerminalUncaughtError(error, stackTrace);
  }

  void _handleTerminalUncaughtError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'what_flutter',
        context:
            ErrorDescription('while invalidating reactive terminal of $widget'),
      ),
    );
  }

  @mustCallSuper
  @override
  void mount(Element? parent, Object? newSlot) {
    terminal.activate();
    super.mount(parent, newSlot);
  }

  @mustCallSuper
  @override
  void activate() {
    super.activate();
    terminal.activate();
  }

  @mustCallSuper
  @override
  void deactivate() {
    terminal.deactivate();
    super.deactivate();
  }

  @mustCallSuper
  @override
  void reassemble() {
    assert(() {
      terminal.debugForceInvalidate();
      return true;
    }());
    super.reassemble();
  }

  @mustCallSuper
  @override
  void unmount() {
    try {
      terminal.deactivate();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'what_flutter',
          context: ErrorDescription(
              'while deactivating terminal in _ReactiveTerminalElementMixin'),
        ),
      );
    }
    super.unmount();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    assert(() {
      final deps = terminal.debugDependencies;
      if (deps.isEmpty) {
        properties.add(
          StringProperty(
            'whatDependencies',
            'none (no active subscriptions)',
            defaultValue: null,
          ),
        );
      } else {
        for (var i = 0; i < deps.length; i++) {
          final dep = deps[i];
          properties.add(
            StringProperty(
              'what[$i]: ${dep.name}',
              dep.description,
              style: DiagnosticsTreeStyle.singleLine,
            ),
          );
        }
      }
      final tethers = terminal.debugTethers;
      if (tethers.isNotEmpty) {
        for (var i = 0; i < tethers.length; i++) {
          final effect = tethers[i];
          final label = effect.debugLabel != null
              ? '${effect.debugLabel} (${effect.runtimeType})'
              : effect.runtimeType.toString();
          properties.add(
            StringProperty(
              'tether[$i]',
              label,
              style: DiagnosticsTreeStyle.singleLine,
            ),
          );
        }
      }
      return true;
    }());
  }
}

/// Element mixin managing an explicit [RawComputedTerminal<Widget>] passing [WhatVia] into builds.
mixin _ViaTerminalElementMixin on ComponentElement
    implements _ReactiveTerminalElementMixin<RawComputedTerminal<Widget>> {
  @override
  late final RawComputedTerminal<Widget> terminal = RawComputedTerminal<Widget>(
    _buildVia,
    onInvalidated: markNeedsBuild,
    onUncaughtError: _handleTerminalUncaughtError,
  );

  /// Evaluates and builds the widget subtree reactively tracking dependencies through [via].
  Widget _buildVia(WhatVia via);

  @override
  Widget build() => terminal.data;

  @mustCallSuper
  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    terminal.markDirty();
    rebuild(force: true);
  }

  @mustCallSuper
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    terminal.markDirty();
  }

  @mustCallSuper
  @override
  void reassemble() {
    terminal.markDirty();
    super.reassemble();
  }
}

/// Element mixin managing a 1:1 single [RawWhatTerminal<T>].
mixin _WhatTerminalElementMixin<T> on ComponentElement
    implements _ReactiveTerminalElementMixin<RawWhatTerminal<T>> {
  /// The upstream [What] source node.
  What<T> get _sourceWhat;

  @override
  late final RawWhatTerminal<T> terminal = RawWhatTerminal<T>(
    _sourceWhat,
    onInvalidated: markNeedsBuild,
    onUncaughtError: _handleTerminalUncaughtError,
  );

  @mustCallSuper
  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    terminal.swapSource(_sourceWhat);
    rebuild(force: true);
  }
}
