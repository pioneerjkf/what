// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:what_flutter/what_flutter.dart';

// =============================================================================
// WhatTestScope & WhatOverride (Scoped Widget Mocking System)
// =============================================================================

/// An immutable declarative override mapping that injects a mock or replacement
/// [What<T>] into descendant widget subtrees via [WhatProvider].
final class WhatOverride<T> {
  /// Creates a [WhatOverride] supplying [replacement] to descendant widgets.
  const WhatOverride({
    required this.replacement,
    this.target,
  });

  /// The mock or replacement [What] node to supply into the widget subtree.
  final What<T> replacement;

  /// The original [What] node being overridden, if specified.
  final What<T>? target;

  /// Wraps [child] in a [WhatProvider<T>] providing this replacement node.
  Widget wrap(Widget child) => WhatProvider<T>(what: replacement, child: child);
}

/// Fluent extensions on [What] for creating [WhatOverride] instances in widget tests.
extension WhatOverrideExtension<T> on What<T> {
  /// Overrides this node's type with a static constant [value].
  WhatOverride<T> overrideWithValue(T value) =>
      WhatOverride<T>(target: this, replacement: What.constant(value));

  /// Overrides this node's type with another reactive [what] node.
  WhatOverride<T> overrideWithWhat(What<T> what) =>
      WhatOverride<T>(target: this, replacement: what);

  /// Overrides this node's type with a permanent error state.
  WhatOverride<T> overrideWithError(Object error, [StackTrace? stackTrace]) =>
      WhatOverride<T>(target: this, replacement: What.error(error, stackTrace));

  /// Overrides this node's type with an empty state and optional [reason].
  WhatOverride<T> overrideWithEmpty([Object? reason]) =>
      WhatOverride<T>(target: this, replacement: What.empty(reason));

  /// Converts this [What] node directly into a [WhatOverride] for [T].
  WhatOverride<T> asOverride() => WhatOverride<T>(replacement: this);
}

/// A scoped testing widget that dynamically wraps descendant widgets with a cascade
/// of [WhatProvider] nodes matching [overrides].
///
/// Any descendant [WhatWidget] reading state via `via.of<T>(context)` or
/// `context.whatOf<T>()` will automatically receive the mock node specified in [overrides].
///
/// ## Examples
/// ```dart
/// await tester.pumpWidget(
///   WhatTestScope(
///     overrides: [
///       userListWhat.overrideWithError(SocketException('Offline')),
///     ],
///     child: const MaterialApp(home: UserScreen()),
///   ),
/// );
/// ```
class WhatTestScope extends StatelessWidget {
  /// Creates a [WhatTestScope] injecting [overrides] into [child].
  const WhatTestScope({
    super.key,
    required this.overrides,
    required this.child,
  });

  /// The list of state overrides to apply to descendant widgets.
  final List<WhatOverride> overrides;

  /// The descendant widget subtree receiving the overridden states.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget current = child;
    for (final override in overrides.reversed) {
      current = override.wrap(current);
    }
    return current;
  }
}
