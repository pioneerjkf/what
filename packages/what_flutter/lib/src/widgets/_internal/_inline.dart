// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../../framework.dart';

// =============================================================================
// Internal Inline Reactive Widgets (ComponentElement Backing)
// =============================================================================

/// Internal reactive widget backing single [What] `(context, data)` extensions.
final class _InlineSingleWhatWidget<T> extends Widget {
  const _InlineSingleWhatWidget({
    super.key,
    required this.what,
    required this.builder,
  });

  final What<T> what;
  final Widget Function(BuildContext context, T data) builder;

  @override
  _InlineSingleWhatElement<T> createElement() =>
      _InlineSingleWhatElement<T>(this);
}

/// Element managing the 1:1 [RawWhatTerminal] for an [_InlineSingleWhatWidget].
final class _InlineSingleWhatElement<T> extends ComponentElement
    with
        _ReactiveTerminalElementMixin<RawWhatTerminal<T>>,
        _WhatTerminalElementMixin<T> {
  _InlineSingleWhatElement(_InlineSingleWhatWidget<T> super.widget);

  @override
  _InlineSingleWhatWidget<T> get widget =>
      super.widget as _InlineSingleWhatWidget<T>;

  @override
  What<T> get _sourceWhat => widget.what;

  @override
  Widget build() => widget.builder(this, widget.what.peek);
}

/// Internal reactive widget backing single [What] `(context, data, child)` extensions.
final class _InlineSingleWhatWithChildWidget<T> extends Widget {
  const _InlineSingleWhatWithChildWidget({
    super.key,
    required this.what,
    required this.builder,
    required this.child,
  });

  final What<T> what;
  final Widget Function(BuildContext context, T data, Widget child) builder;
  final Widget child;

  @override
  _InlineSingleWhatWithChildElement<T> createElement() =>
      _InlineSingleWhatWithChildElement<T>(this);
}

/// Element managing the 1:1 [RawWhatTerminal] with cached child fallback for an [_InlineSingleWhatWithChildWidget].
final class _InlineSingleWhatWithChildElement<T> extends ComponentElement
    with
        _ReactiveTerminalElementMixin<RawWhatTerminal<T>>,
        _WhatTerminalElementMixin<T> {
  _InlineSingleWhatWithChildElement(
      _InlineSingleWhatWithChildWidget<T> super.widget);

  @override
  _InlineSingleWhatWithChildWidget<T> get widget =>
      super.widget as _InlineSingleWhatWithChildWidget<T>;

  @override
  What<T> get _sourceWhat => widget.what;

  @override
  Widget build() {
    if (!widget.what.peekState.hasData) {
      return widget.child;
    }
    return widget.builder(this, widget.what.peek, widget.child);
  }
}

/// Internal reactive widget backing single [What] `(context, data, children)` extensions.
final class _InlineSingleWhatWithChildrenWidget<T> extends Widget {
  const _InlineSingleWhatWithChildrenWidget({
    super.key,
    required this.what,
    required this.builder,
    required this.children,
  });

  final What<T> what;
  final Widget Function(BuildContext context, T data, List<Widget> children)
      builder;
  final List<Widget> children;

  @override
  _InlineSingleWhatWithChildrenElement<T> createElement() =>
      _InlineSingleWhatWithChildrenElement<T>(this);
}

/// Element managing the 1:1 [RawWhatTerminal] with cached children for an [_InlineSingleWhatWithChildrenWidget].
final class _InlineSingleWhatWithChildrenElement<T> extends ComponentElement
    with
        _ReactiveTerminalElementMixin<RawWhatTerminal<T>>,
        _WhatTerminalElementMixin<T> {
  _InlineSingleWhatWithChildrenElement(
      _InlineSingleWhatWithChildrenWidget<T> super.widget);

  @override
  _InlineSingleWhatWithChildrenWidget<T> get widget =>
      super.widget as _InlineSingleWhatWithChildrenWidget<T>;

  @override
  What<T> get _sourceWhat => widget.what;

  @override
  Widget build() {
    if (!widget.what.peekState.hasData) {
      return const SizedBox.shrink();
    }
    return widget.builder(this, widget.what.peek, widget.children);
  }
}
