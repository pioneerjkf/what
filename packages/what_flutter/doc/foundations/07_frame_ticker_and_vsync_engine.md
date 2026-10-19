# Frame Ticker Scheduler & VSYNC Pipeline Engine Specification
## (Frame Ticker Scheduler & VSYNC Pipeline Engine: composed.drive)

> **"Unconstrained 120Hz VSYNC ticks routed directly into widget rebuilds drain batteries and heat mobile devices. What pairs `managed` resource lifecycles with `distinct` equality filtering to deliver a high-refresh VSYNC engine that minimizes CPU consumption."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Collision of High-Frequency VSYNC Ticks and Reactive Rendering

Modern mobile displays (Apple 120Hz ProMotion, high-refresh Android panels) emit VSYNC frame pulses every 8.3 milliseconds.

When modeling continuous physical motions or time streams, developers face critical hurdles:
1. **Excessive Rebuilds and Battery Drain**:
   Calling `setState` on every tick via `Ticker` or `Timer.periodic` triggers 60 to 120 full-widget rebuilds per second even when values remain static.
2. **Ticker Leaks and Background Crashes**:
   Failing to cancel VSYNC tickers when widgets navigate off-screen causes `Ticker.dispose` assertion failures and drains battery in the background.
3. **Phase Mismatches Between Compute Ticks and Display Refreshes**:
   Evaluating state via asynchronous timers independent of display refresh ticks causes micro-stuttering.

`package:what_flutter` resolves these issues via **`TickerProvider.drive<T>()`** and **`composed.drive(...)`**.

---

## 2. VSYNC Engine Architecture

The VSYNC engine integrates directly with Flutter's `TickerProvider` lifecycle via the `managed` functor:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   VSYNC Engine Architecture & Pipeline                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Host Element / TickerProvider Source ]                             │
│   Provides TickerProvider                                              │
│          │                                                             │
│          ▼                                                             │
│   managed<_TickerDriver<T>> Pipeline                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │ • create: Instantiates _TickerDriver(vsync, onTick)            │   │
│   │ • dispose: Cancels ticker & frees memory on unmount            │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    │                                   │
│   [ Hardware VSYNC Tick (Every 8.3ms at 120Hz) ]                       │
│          │                                                             │
│          ▼                                                             │
│   onTick(elapsed: Duration) ──► Produces State Value [T]               │
│          │                                                             │
│          ▼                                                             │
│   [ Distinct Filter: value == previousValue? ]                         │
│          ├─► (Yes) ──► DROP Invalidation! (Rebuild Count: 0)           │
│          │             Saves CPU, Battery, and Layout Cycles!          │
│          │                                                             │
│          └─► (No)  ──► Topological Push-Dirty to Terminal              │
│                        (Surgical Leaf Rebuild: Rebuild Count: 1)       │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Foundational Architecture Invariants

### Invariant 1: Zero-Leak Lifecycles via `managed`
```dart
// lib/src/scheduler/ticker.dart
final resourceNode = managed<_TickerDriver<T>>(
  eager: true,
  create: (via) {
    return _TickerDriver<T>(
      this,
      onTick: onTick,
      initialValue: initialValue,
      distinct: distinct,
      equals: equals,
    );
  },
  dispose: (driver) {
    driver.tryDispose(this);
  },
  graceful: graceful,
);
```
- Tickers run exclusively while active subscribers observe the node.
- When widgets unmount or tabs switch, `dispose` triggers, stopping VSYNC listeners immediately and eliminating memory leaks.

### Invariant 2: Tick Dropping via `distinct` Filtering
- While `onTick(elapsed)` evaluates on every 8.3ms frame tick, if the output value (e.g., elapsed seconds `elapsed.inSeconds % 60`) equals the previous value, the LPDAG **drops the downstream invalidation pulse immediately**.
- **Outcome**: The display monitors 120Hz VSYNC pulses while UI widget rebuilds fire strictly when the derived value changes (e.g., exactly once per second).

---

## 4. Production Code Patterns

### 1. Declarative Clock Hand Driver via `composed.drive`
```dart
class AnalogClockWidget extends StatelessWidget {
  const AnalogClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return composed.drive<double>(
      // Translates frame ticks into continuous rotational angles:
      (elapsed) {
        final milliseconds = DateTime.now().millisecond;
        final seconds = DateTime.now().second;
        return (seconds + milliseconds / 1000.0) * (2 * 3.141592653589793 / 60.0);
      },
      (context, via, secondAngle) => Transform.rotate(
        angle: secondAngle,
        child: const Placeholder(),
      ),
      distinct: false, // 120Hz smooth sweep
    );
  }
}
```

### 2. Inline Frame Driver (`composed.drive`)
Inline frame drivers can be composed inside any widget tree with custom progress calculations:

```dart
class PulsingRadarDot extends StatelessWidget {
  const PulsingRadarDot({super.key});

  @override
  Widget build(BuildContext context) {
    return composed.drive<double>(
      // Oscillates 0.0 to 1.0 on a 1-second period
      (elapsed) => (elapsed.inMicroseconds % 1000000) / 1000000.0,
      (context, via, progress) => Opacity(
        opacity: 1.0 - progress,
        child: Transform.scale(
          scale: 1.0 + progress * 2.0,
          child: const CircleAvatar(radius: 12, backgroundColor: Colors.blue),
        ),
      ),
    );
  }
}
```

### 3. Raw VSYNC Acquisition (`WhatVsyncWidget` & `composed.vsync`)
When you need direct access to a `TickerProvider` (e.g., to instantiate `AnimationController` or pass to legacy Flutter code) without the overhead of `StatefulWidget` and `SingleTickerProviderStateMixin`, use `WhatVsyncWidget` or `composed.vsync`:

```dart
// [Recommended] 1. Class-Based VSYNC Acquisition
base class AnimatedHeroScreen extends WhatVsyncWidget {
  const AnimatedHeroScreen({super.key});

  @override
  Widget build(BuildContext context, WhatVia via, TickerProvider vsync) {
    // vsync is available seamlessly:
    final controller = AnimationController(vsync: vsync, duration: const Duration(seconds: 1));
    return FadeTransition(opacity: controller, child: const Placeholder());
  }
}

// [Recommended] 2. Inline VSYNC Acquisition
class InlineAnimatedWidget extends StatelessWidget {
  const InlineAnimatedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return composed.vsync((context, via, vsync) {
      final controller = AnimationController(vsync: vsync, duration: const Duration(seconds: 1));
      return FadeTransition(opacity: controller, child: const Text('Fading!'));
    });
  }
}
```

---

## 5. Architectural Conclusions

What's VSYNC engine unlocks 120Hz display fluidity while eliminating redundant widget rebuilds through intelligent equality gating and managed lifecycle supervision.
