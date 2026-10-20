// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// Interactive showcase example application for `package:what_flutter`.
///
/// Demonstrates all 18 core reactive architecture sections from the README:
/// 1. WhatWidget & Dynamic Dependency Discovery
/// 2. Declarative Inline Composition (composed)
/// 3. Direct Value Functors (what.build & Tuple Whats)
/// 4. Scoped State DI (`what.provide` & `whatOf<T>()`)
/// 5. Standard Form Input & Listenable Bridge (toWhatBy)
/// 6. Async UI, SWR & WhatPendingIndicator
/// 7. Imperative Signals vs State Anti-Pattern (WhatListener)
/// 8. Scroll Kinematics & 120fps Surgical Micro-Rebuilds
/// 9. Reactive Effects & Side-Effect Pipeline (Effect.via)
/// 10. Temporal Pipelines (Debounce & Throttle)
/// 11. Foundation & Listenable Bridges (toWhat & toListenable)
/// 12. Adaptive Material & Cupertino Design Proxies
/// 13. Dual Engine Battle & Unbounded Motion (resume vs catchUp & -1000~+5000)
/// 14. Tri-Pattern Animation Matrix (composed.animate, ctrl.animate, ctrl.animate.child)
/// 15. Composite Motion & Multi-Tween Choreography (Single Master VSYNC)
/// 16. Frame-Aligned Scheduler & Inline composed.drive
/// 17. Physics Dynamics & Simulation Flapping Lab (Spring, Gravity, Friction & 30x Stress)
/// 18. Google Adversarial & Dormant Motion Staging Lab (1000x Flapping & Queue Staging)
library;

import 'package:what_flutter_example/main.dart' as showcase;

void main() {
  showcase.main();
}
