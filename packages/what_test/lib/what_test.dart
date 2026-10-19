// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// Pure Dart declarative testing harness and LPDAG custom matchers for the What framework.
///
/// Provides [whatTest] declarative runner, [FakeAsync] virtual time fast-forwarding,
/// and custom LPDAG matchers ([isDormant], [isActive], [hasSubscribers], [hasGlitchFreedom],
/// [isData], [isEmptyState], [isErrorState]).
library what_test;

// Re-export core testing utilities from package:test
export 'package:test/test.dart';

// Re-export core reactive state engine from package:what
export 'package:what/what.dart';
export 'package:what/effect.dart';

// Export what_test specialized testing harness
export 'src/matchers.dart';
export 'src/runner.dart';
