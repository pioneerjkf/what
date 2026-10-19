// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'src/framework.dart';
///
/// Zero-overhead diagnostic reflector and LPDAG topology inspection suite.
///
/// `package:what/reflector.dart` provides low-level reflection interfaces and
/// diagnostic data snapshot handles used by Flutter DevTools (`package:what_devtools`),
/// VM Service RPC extensions, and topological verification suites.
///
/// ## Core Diagnostic Capabilities
///
/// 1. **LpdagReflector**: Diagnostic interface for any reactive LPDAG vertex
///    (sources, derivations, sinks, resources, tethers).
/// 2. **WhatReflector**: Specialized reactive reflector exposing the 3-state FSM ([WhatState]),
///    live payload, and point-in-time snapshots.
/// 3. **WhatDebugSnapshot**: Immutable, serializable diagnostic record capturing
///    node metadata, version, active subscribers, and payload.
/// 4. **LpdagStatusReflectorExtension**: Extension getter providing zero-overhead `.debugReflector`
///    to any [LpdagStatus] node.
library;

export 'src/framework.dart'
    show LpdagStatus, LpdagStatusReflectorExtension, LpdagReflector, WhatReflector, WhatDebugSnapshot;
