// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport '../../../framework.dart';
///
/// Internal testing utilities and test harnesses for Durable Animation engines.
///
/// Exposes [DurableAnimationTestingExtension] and [TestDurableVSync] strictly for headless
/// framework test suites and unit testing harnesses. In standard widget development, controllers
/// couple to VSYNC automatically via `composed.animate` without requiring manual lifecycle hooks.
///
/// ## Examples
/// ```dart
/// import 'package:flutter_test/flutter_test.dart';
/// import 'package:what_flutter/src/animation/durable/testing.dart';
///
/// void main() {
///   test('durable controller progresses with headless test vsync', () {
///     final vsync = const TestDurableVSync();
///     final controller = DurableAnimationController(
///       duration: const Duration(milliseconds: 300),
///     )..wake(vsync);
///
///     controller.forward();
///     expect(controller.isAnimating, isTrue);
///   });
/// }
/// ```
library;

export '../../../framework.dart'
    show DurableAnimationTestingExtension, TestDurableVSync;
export '../../../what_flutter.dart';
