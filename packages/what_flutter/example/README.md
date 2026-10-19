# What Flutter Interactive Showcase & Verification Lab

A comprehensive reference implementation and visual laboratory demonstrating the core architecture, reactive primitives, zero-rebuild inline trees, scoped dependency injection, and exhaustive 35-case animation engines of the `what_flutter` framework.

---

## 1. Design Philosophy and Purpose

The `what_flutter_example` application serves a dual purpose:

1. **Canonical Developer Experience (DX) Reference**: An architectural showcase demonstrating idiomatic patterns, zero prop-drilling state management, and type-safe reactive UI composition without global singletons or code generation.
2. **Human-in-the-Loop Verification Laboratory**: An exhaustive interactive testing suite designed for developers and QA engineers to visually verify every edge case, dormant motion staging queue, wall-clock time warp, and rapid lifecycle transition across Flutter desktop, mobile, and web targets.

---

## 2. System Architectural Flow

```
[ShowcaseStore (Root State Container)]
        │
        ▼ (store.provide())
[WhatProvider<ShowcaseStore>] (Injected at Root MaterialApp)
        │
        ▼ (whatOf<ShowcaseStore>())
[ShowcaseShell / Responsive SplitLayout]
   ├── [Left Navigation Drawer] (18 Canonical Chapters)
   └── [Right Master Viewport]
        ├── [Interactive Visual Arena] (60/120fps Dynamic Renders)
        ├── [Live Staged Action / Adversarial Consoles]
        └── [1:1 Synchronized DX Code Viewer & Roadmap Trees]
```

---

## 3. Master Showcase Navigation Index

The application is structured into 18 distinct, self-contained chapters covering every aspect of the framework, organized by progressive disclosure:

```
[What Flutter Showcase Master Index]
 ├── [Tier 1: Core State & Composition 01~04]
 │    ├── 01. WhatWidget & Dynamic Discovery
 │    ├── 02. Inline Functors & Zero-Cost Trees (composed)
 │    ├── 03. what.build & Direct Value Cascades
 │    └── 04. Scoped State DI (what.provide / whatOf)
 │
 ├── [Tier 2: Real-World App Essentials 05~10]
 │    ├── 05. Zero-Jump Form Binding & WhatTextEditingController
 │    ├── 06. Async UI, SWR & WhatPendingIndicator
 │    ├── 07. Imperative Signals vs State Anti-Pattern (WhatListener)
 │    ├── 08. Scroll Kinematics & 120fps Surgical Micro-Rebuilds
 │    ├── 09. Reactive Effects & Side-Effect Pipeline (Effect.via)
 │    └── 10. Temporal Pipelines & Rate-Limiting (Debounce & Throttle)
 │
 ├── [Tier 3: Platform & Ecosystem Bridges 11~12]
 │    ├── 11. Foundation & Listenable Bridges (toWhat, toListenable, toValueNotifier)
 │    └── 12. Adaptive Material & Cupertino Design (Theme & Platform Integration)
 │
 ├── [Tier 4: Durable Animation & Frame Scheduling 13~16]
 │    ├── 13. Dual Engine Battle & Unbounded Motion (Frozen vs Catch-Up & -1000~+5000)
 │    ├── 14. Tri-Pattern Animation Matrix (composed.animate, ctrl.animate, ctrl.animate.child)
 │    ├── 15. Composite Motion & Multi-Tween Choreography (Single Master VSYNC)
 │    └── 16. Frame-Aligned Scheduler & Inline composed.drive
 │
 └── [Tier 5: Hardcore Verification & Adversarial Lab 17~18]
      ├── 17. Physics Dynamics & Simulation Flapping Lab (Spring, Gravity, Friction & 30x Stress)
      └── 18. Google Adversarial & Dormant Motion Staging Lab (1000x Flapping & Queue Staging)
```

---

## 4. Chapter Breakdown and Verification Matrices

### 4.1. Core State & Composition (Chapters 01 - 04)

* **01. WhatWidget & Dynamic Discovery (`01_watch_widget`)**: Demonstrates dynamic dependency tracking via explicit `WhatVia` manifest with 1-Pass Epoch Sweeping. Rebuilds surgically only when accessed What nodes change distinct value (`distinct: true`).
* **02. Inline Functors (`02_composed_functors`)**: Zero-boilerplate inline reactive widgets via `composed((via) => ...)` without requiring standalone `StatefulWidget` or `WhatWidget` classes. Supports `.context`, `.child`, and `.children` static subtree caching.
* **03. Direct Value Cascades (`03_what_build_tuple`)**: Zero-allocation single-value reactive building via `what.build((val) => ...)` and multi-node dynamic discovery via `composed((via) => ...)`.
* **04. Scoped State DI (`04_scoped_state_di`)**: Hierarchical, type-safe dependency injection via `store.provide(child: ...)` and `whatOf<T>()`, eliminating prop-drilling across deep widget subtrees.

---

### 4.2. Real-World App Essentials (Chapters 05 - 10)

* **05. Zero-Jump Form Binding (`05_text_editing_controller`)**: Eliminates cursor jumping, infinite echo loops, and text input lag during bi-directional reactive form sync via `WhatTextEditingController`, fine-grained `Graceful` debounce policies, and clean auto-disposal.
* **06. Async UI, SWR & WhatPendingIndicator (`06_async_swr_builder`)**: Declarative 4-state asynchronous building (`data`, `loading`, `error`, `empty`), flicker-free Stale-While-Revalidate (SWR) cache retention, surgical linear `WhatPendingIndicator` bound directly to `What<bool>`, and zero-alloc `what.build.async` inline functor cascades.
* **07. Imperative Signals vs State Anti-Pattern (`07_imperative_signals`)**: Transient one-off signals (`WhatSignalController`) vs persistent boolean state, showing how `WhatListener` eliminates zombie dialog states upon remount.
* **08. Scroll Kinematics & 120fps Surgical Micro-Rebuilds (`08_scroll_kinematics`)**: High-frequency scroll tracking via `scrollController.toWhatBy(...)` where a heavy 100-item ListView NEVER rebuilds, and only the lightweight AppBar Opacity updates at 120fps.
* **09. Reactive Effects & Side-Effect Pipeline (`09_reactive_effects`)**: Isolated reactive side-effects executing without UI widget rebuilds (`Rebuild Count: 0`), explicit dynamic branch discovery (`Effect.via`), untracked boundary protection, explicit tuple effects (`(a, b).effect`), direct unary effect (`source.effect`), and full lifecycle management (`activate`, `deactivate`, `dispose`).
* **10. Temporal Pipelines & Rate-Limiting (`10_temporal_orchestration`)**: Leading/trailing debounce and throttle rate-limiting pipelines.

---

### 4.3. Platform & Ecosystem Bridges (Chapters 11 - 12)

* **11. Foundation Bridges (`11_foundation_bridge`)**: Bidirectional zero-cost adapters converting Flutter `Listenable` / `ValueNotifier` / `TextEditingController` into reactive `What<T>` nodes and vice versa.
* **12. Adaptive Platform Integration (`12_adaptive_proxies`)**: Type-safe adaptive style and theme resolution supporting Material 3 and Cupertino styles.

---

### 4.4. Durable Animation & Frame Scheduling (Chapters 13 - 16)

```
[DurableAnimationController Engine Hierarchy]
 ├── DurabilityPolicy.resume (Freeze on unmount & staged replay)
 ├── DurabilityPolicy.catchUp (Wall-clock time continuity during dormancy)
 └── DurabilityPolicy.reset (Reset to initial value upon dormancy)
```

* **13. Dual Engine Battle & Unbounded Motion (`13_dual_engine_battle`)**: Side-by-side comparison of `Frozen` and `CatchUp` engines with both Planetary Orbit mode and Unbounded Space navigation (`-1000.0` to `+5000.0`). Interactive 3-second simulated dormancy verifies that Frozen preserves exact progress while CatchUp compensates for real-world elapsed time.
* **14. Tri-Pattern Animation Matrix (`14_tri_pattern_matrix`)**: Validates the 3 canonical pathways to bind external Store controllers to Flutter Vsync (`composed.animate`, `ctrl.animate`, and `ctrl.animate.child`).
* **15. Composite Motion & Multi-Tween Choreography (`15_composite_motion`)**: Demonstrates a single master `DurableAnimationController` orchestrating multiple sub-animations, curved intervals (`Interval`), chained curves (`Tween.chain(CurveTween)`), `TweenSequence` weighted keyframes, and diverse multi-property tweens (`ColorTween`, `BorderRadiusTween`, `Tween<Offset>`, `Tween<double>`) under 1 VSYNC authority without ticker leaks or rebuild overhead.
* **16. Frame-Aligned Scheduler (`16_frame_scheduler`)**: High-cadence 60fps/120fps frame-tick pipelines via `vsync.drive` and `composed.drive.child` with static child repaint caching.

---

### 4.5. Hardcore Verification & Adversarial Lab (Chapters 17 - 18)

* **17. Physics Dynamics & Simulation Flapping Lab (`17_physics_bounds`)**: Real-time slider control over Flutter physics simulations (`SpringSimulation`, `GravitySimulation`, `FrictionSimulation`) paired with high-frequency 20ms mount/unmount flapping stress testing under active physics.
* **18. Google Adversarial & Dormant Motion Staging Lab (`18_google_adversarial`)**: High-frequency lifecycle stress suite executing 1,000+ rapid mount/unmount flapping cycles, NTP clock rewinds (-1h time-warps), and dormant command staging queueing (`forward()`, `reverse()`, `fling()` while unmounted with 0 TickerCanceled exceptions).

---

## 5. Running the Showcase Application

### Prerequisites
* Flutter SDK (3.x or higher)
* Dart SDK (3.x or higher)

### Desktop (Windows, macOS, Linux)
```bash
# Navigate to the example directory
cd packages/what_flutter/example

# Run on your desktop platform
flutter run -d windows    # On Windows
flutter run -d macos      # On macOS
flutter run -d linux      # On Linux
```

### Web
```bash
flutter run -d chrome
```

### Mobile (iOS / Android)
```bash
flutter run -d <device_id>
```

---

## 6. Testing & Quality Verification

The example suite includes comprehensive automated widget and integration tests verifying all 18 sections:

```bash
# Run all example tests
flutter test

# Run static analysis
flutter analyze
```

### Key Automated Invariants Tested
1. **Zero Ticker Leaks**: Every ticker is disposed cleanly when navigating between sections.
2. **Dormant State Preservation**: Controllers preserve exact values and directions across tab switching.
3. **No Overflow Guarantee**: `LayoutBuilder` responsive layouts adapt cleanly to narrow split-view viewports without RenderFlex overflow.
