// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
part of '../../framework.dart';

// =============================================================================
// WhatAsyncBuilder: Declarative 4-State Async Branching & SWR Preservation
// =============================================================================

/// A declarative reactive widget providing structured 4-state asynchronous branching
/// (`data`, `loading`, `error`, `empty`) with native Stale-While-Revalidate (SWR) preservation.
///
/// Seamlessly maps What's 3-State reactive model along with collection emptiness onto
/// dedicated UI builders, preventing nested if-else ladders and eliminating UI flicker during background refresh.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                       WhatAsyncBuilder Flow                            │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │                           [ Upstream What<T> ]                         │
/// │                                     │                                  │
/// │                   ┌─────────────────┴─────────────────┐                │
/// │                   ▼                                   ▼                │
/// │             [ hasData: true ]                   [ hasData: false ]     │
/// │                   │                                   │                │
/// │            ┌──────┴──────┐                     ┌──────┴──────┐         │
/// │            ▼             ▼                     ▼             ▼         │
/// │        [ Empty? ]  [ Valid Data ]       [ hasError? ]   [ isEmpty? ]   │
/// │            │             │                     │             │         │
/// │            ▼             ▼                     ▼             ▼         │
/// │         empty()       data()                error()       loading()    │
/// │                                                                        │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Flicker-Free SWR (Stale-While-Revalidate)**: When [preserveDataOnPending] is `true` (the default)
///    and the upstream node retains prior valid data (e.g. via `source.retained`), background re-evaluations
///    do not trigger the [loading] placeholder. The previous valid data view remains fully rendered and active.
/// 2. **Automatic Collection Emptiness Detection**: If [empty] is provided and the valid payload is an empty
///    [Iterable] or [Map], routes automatically to [empty].
/// 3. **Deterministic 4-State UI Branching**: Eliminates nested conditionals and ternary cascades across
///    asynchronous boundaries.
/// 4. **Sound Explicit Empty vs. Uninitialized Loading**: Explicit `emptyReason` routes to [empty],
///    while uninitialized state (`emptyReason == null`) routes to [loading].
///
/// **Warning (Anti-Pattern Prevention):**
/// - Avoid creating async state pipelines inside `build` methods without caching; always connect
///   [what] to a persistent state node (e.g. `computed.future` or `stream.toWhat`).
///
/// **BAD:**
/// ```dart
/// // [Anti-Pattern] Pipeline recreated per build pass
/// Widget build(BuildContext context) {
///   return WhatAsyncBuilder(
///     what: myFuture.toWhat(), // Re-evaluates every frame!
///     data: (context, data) => Text('$data'),
///     loading: (context) => const CircularProgressIndicator(),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // [Recommended] Connect to cached controller or derived pipeline
/// WhatAsyncBuilder<UserProfile>(
///   what: profileWhat,
///   data: (context, user) => ProfileCard(user: user),
///   loading: (context) => const ShimmerPlaceholder(),
/// );
/// ```
///
/// ## Examples
/// ```dart
/// WhatAsyncBuilder<UserProfile>(
///   what: userProfileWhat,
///   data: (context, user) => ProfileCard(user: user),
///   loading: (context) => const ShimmerPlaceholder(),
///   error: (context, error, stack) => ErrorRetryButton(error: error),
///   empty: (context) => const EmptyProfileNotice(),
/// );
/// ```
final class WhatAsyncBuilder<T> extends WhatWidget {
  /// Creates a structured 4-state asynchronous branching widget.
  ///
  /// * [what]: The upstream reactive [What] node to observe.
  /// * [data]: Builder callback invoked when valid payload data of type [T] is present.
  /// * [loading]: Builder callback invoked when the node is in uninitialized or loading state.
  /// * [error]: Optional builder callback invoked when an error occurs during evaluation.
  /// * [empty]: Optional builder callback invoked when data is empty or node is explicitly empty.
  /// * [pending]: Optional pending indicator pipeline [What<bool>].
  /// * [preserveDataOnPending]: Whether to retain prior valid data during background re-evaluation. Defaults to `true`.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [what], [data], and [loading] must not be null.
  ///
  /// **Ensures:**
  /// * Returns a reactive [WhatWidget] handling all 4 asynchronous states cleanly with optional SWR retention.
  const WhatAsyncBuilder({
    super.key,
    required this.what,
    required this.data,
    required this.loading,
    this.error,
    this.empty,
    this.pending,
    this.preserveDataOnPending = true,
  });

  /// The upstream reactive [What] node being observed.
  final What<T> what;

  /// Optional pending indicator pipeline [What<bool>].
  ///
  /// When provided and [preserveDataOnPending] is `false`, renders [loading]
  /// whenever background re-evaluation is in progress.
  final What<bool>? pending;

  /// Builder callback invoked when valid payload data is available.
  final Widget Function(BuildContext context, T data) data;

  /// Builder callback invoked when the node is in its initial uninitialized or loading state.
  final Widget Function(BuildContext context) loading;

  /// Optional builder callback invoked when an error occurs during evaluation.
  final Widget Function(
      BuildContext context, Object error, StackTrace stackTrace)? error;

  /// Optional builder callback invoked when data is empty or node is explicitly empty.
  final Widget Function(BuildContext context)? empty;

  /// Whether to retain and render the previous valid data during background re-evaluation.
  ///
  /// Defaults to `true` (Flicker-Free SWR).
  final bool preserveDataOnPending;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final target = via.state(what);

    // If SWR is disabled and node is actively re-evaluating in background, show loading
    if (!preserveDataOnPending && pending != null) {
      if (via(pending!)) {
        return loading(context);
      }
    }

    return switch (target.phase) {
      WhatPhase.valid => _buildData(context, target.data),
      WhatPhase.error => _buildError(context, target.error, target.stackTrace),
      WhatPhase.empty => _buildEmptyOrLoading(context, target.emptyReason),
    };
  }

  Widget _buildData(BuildContext context, T payload) {
    if (empty != null) {
      if (payload is Iterable && payload.isEmpty) {
        return empty!(context);
      }
      if (payload is Map && payload.isEmpty) {
        return empty!(context);
      }
    }
    return data(context, payload);
  }

  Widget _buildError(
      BuildContext context, Object errorObj, StackTrace stackTrace) {
    if (error != null) {
      return error!(context, errorObj, stackTrace);
    }
    return ErrorWidget.withDetails(
      message: 'Uncaught error in WhatAsyncBuilder: $errorObj',
      error: errorObj is FlutterError ? errorObj : null,
    );
  }

  Widget _buildEmptyOrLoading(BuildContext context, Object? emptyReason) {
    if (empty != null && emptyReason != null) {
      return empty!(context);
    }
    return loading(context);
  }
}

// =============================================================================
// WhatPendingIndicator: Surgical Isolated Pending Progress Indicator
// =============================================================================

/// A surgical, non-intrusive pending progress indicator that isolates background re-evaluation
/// signals from the primary UI view tree.
///
/// Implements [PreferredSizeWidget] for direct embedding into [AppBar.bottom], [Scaffold],
/// or top-level layout headers.
///
/// ## System Architectural Flow
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────┐
/// │                     WhatPendingIndicator SWR Flow                      │
/// ├────────────────────────────────────────────────────────────────────────┤
/// │                                                                        │
/// │         [ Upstream SWR: source.retained(pending: pendingCoupler) ]      │
/// │                                     │                                  │
/// │        ┌────────────────────────────┴────────────────────────────┐     │
/// │        ▼                                                         ▼     │
/// │   Primary Data (What<T>)                                Coupler (What<bool>)
/// │        │                                                         │     │
/// │        ▼                                                         ▼     │
/// │   [NewsListView] (Intact! Rebuild count: 0)        [WhatPendingIndicator]│
/// │                                                    (Rebuilds surgically!)
/// │                                                                        │
/// └────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Key Invariants & Architectural Benefits
/// 1. **Zero Primary Rebuilds**: Renders background pending signals without invalidating
///    or rebuilding the main data view subtree.
/// 2. **Continuous Frame Driving**: Driven by [ComposedDriveFunctor] (`composed.drive`) for smooth 60/120fps progress
///    animation without manual ticker controllers.
/// 3. **App Header Compatibility**: Implements [PreferredSizeWidget] for drop-in embedding in [AppBar.bottom].
///
/// ## Examples
/// ```dart
/// final pendingCoupler = WhatCoupler<bool>.late();
/// late final newsFeedWhat = remoteFeed.retained(pending: pendingCoupler);
///
/// Widget build(BuildContext context) {
///   return Scaffold(
///     appBar: AppBar(
///       title: const Text('Live Feed'),
///       bottom: WhatPendingIndicator(target: pendingCoupler.what),
///     ),
///     body: composed((context, via) => NewsListView(via(newsFeedWhat))),
///   );
/// }
/// ```
final class WhatPendingIndicator extends WhatWidget
    implements PreferredSizeWidget {
  /// Creates a surgical isolated pending progress indicator.
  ///
  /// * [target]: The reactive [What<bool>] indicator node.
  /// * [height]: The indicator height in logical pixels. Defaults to `2.0`.
  /// * [color]: Foreground progress bar color.
  /// * [backgroundColor]: Background track color.
  /// * [builder]: Optional custom painter/builder callback.
  /// * [key]: Optional widget key.
  ///
  /// **Requires:**
  /// * [target] must not be null.
  /// * [height] must be non-negative.
  ///
  /// **Ensures:**
  /// * Returns a [PreferredSizeWidget] rendering an animated progress bar when [target] is `true`.
  const WhatPendingIndicator({
    super.key,
    required this.target,
    this.height = 2.0,
    this.color,
    this.backgroundColor,
    this.builder,
  });

  /// The target reactive node providing the pending boolean signal.
  final What<bool> target;

  /// The height of the pending indicator (defaults to 2.0).
  final double height;

  /// Foreground active progress indicator color (defaults to `Color(0xFF2196F3)`).
  final Color? color;

  /// Background track color (defaults to transparent `Color(0x00000000)`).
  final Color? backgroundColor;

  /// Optional custom builder for full indicator rendering customization.
  final Widget Function(BuildContext context, bool isPending)? builder;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WhatVia via) {
    final isPending = via(target);

    if (builder != null) {
      return builder!(context, isPending);
    }

    if (!isPending) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: composed.drive<double>(
        (elapsed) => (elapsed.inMicroseconds % 1200000) / 1200000.0,
        (context, via, progress) => CustomPaint(
          size: Size(double.infinity, height),
          painter: _PendingBarPainter(
            progress: progress,
            color: color ?? const Color(0xFF2196F3),
            backgroundColor: backgroundColor ?? const Color(0x00000000),
          ),
        ),
      ),
    );
  }
}

/// Indeterminate sliding bar canvas painter for [WhatPendingIndicator].
final class _PendingBarPainter extends CustomPainter {
  const _PendingBarPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor.a > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor,
      );
    }

    final barWidth = size.width * 0.35;
    final totalSpan = size.width + barWidth;
    final startX = (progress * totalSpan) - barWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, 0, barWidth, size.height),
        Radius.circular(size.height / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PendingBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}
