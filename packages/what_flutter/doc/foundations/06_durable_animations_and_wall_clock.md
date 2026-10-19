# Durable Animations & Wall-Clock Compensation Invariants Specification
## (Durable Animations, Inversion-of-Control Dormancy & Single VSYNC Authority)

> **"When a user switches tabs or navigates away, clocks freezing or radar sweeps restarting from zero represents a flaw in UI engineering. True reactive UI must preserve physical continuity across element lifecycle destructions."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: Flutter Tickers and Widget Lifecycle Disruptions

Standard Flutter [AnimationController] handles bind directly to a hosting widget's [TickerProvider] (`vsync`). However, production mobile and desktop applications encounter frequent lifecycle interruptions:

1. **Tab Switching & Route Navigation Lifecycle Drop**:
   When a widget subtree unmounts or deactivates, its underlying [Ticker] cancels (`TickerCanceled`), aborting running animations, dropping in-flight progress, and requiring complex boilerplate to reconstruct.
2. **App Backgrounding & Real-World Wall-Clock Desynchronization**:
   Continuous real-time motions (radar sweeps, clock dials, video progress scrubbers, live telemetry feeds) freeze when hidden. Returning to the screen reveals jarring jumps or resets back to zero, destroying temporal continuity.
3. **The "Disposal Ceremony" Anti-Pattern & Memory Leaks**:
   Standard [AnimationController] instances impose a manual disposal burden (`controller.dispose()`) because raw [Ticker] instances couple tightly to host widgets. Omitting disposal leaks tickers; invoking disposal prematurely invalidates shared controllers while dormant navigation stacks or sibling proxies still reference them. Moreover, invoking animation directives (`forward()`, `repeat()`) on detached controllers triggers framework assertions.

`package:what_flutter` resolves these challenges through the **Durable Animation Hierarchy**, providing state durability, physical continuity, and an Inversion-of-Control (IoC) dormancy model that completely eliminates manual ticker management.

---

## 2. Canonical Durable Animation Controller Hierarchy & Type Architecture

In `what_flutter`, the durable animation system separates the public controller lifecycle contract from the element-scoped presentation view:

```text
DurableAnimationController (sealed class: public timeline & motion contract)
 ├── _FrozenAnimationController   (concrete engine: DurabilityPolicy.resume & reset)
 └── _CatchUpAnimationController  (concrete engine: DurabilityPolicy.catchUp)

ScopedAnimationController (abstract interface class: presentation view facet)
 └── _ScopedDurableAnimationControllerProxy (element-scoped proxy isolating view & listeners)
```

```text
┌────────────────────────────────────────────────────────────────────────┐
│               Durable Animation Controller Architecture                │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Active State: Bound to Authoritative VSYNC Socket ]                │
│   Host Element (composed.animate) ──► Active Engine (_ActiveDelegate)  │
│                                           │ Drives 60/120 FPS Ticker   │
│                                           ▼                            │
│   [ Event: Host Widget Unmounts / Navigates Away ]                     │
│   Engine deactivates -> Preserves parameters & stages motion locally   │
│                                           │                            │
│   [ Branch A: DurabilityPolicy.resume ]   │                            │
│   • Progress frozen at exact value (e.g. 0.518).                       │
│   • On remount: Resumes via _TimeOffsetSimulation from 0.518!          │
│                                                                        │
│   [ Branch B: DurabilityPolicy.catchUp ]  │                            │
│   • Captures deactivation timestamp (clock()).                         │
│   • While dormant: Pure reads project value across elapsed Δt.         │
│   • On remount: Compensates Δt and instantiates active engine!         │
│                                                                        │
│   [ Branch C: DurabilityPolicy.reset ]    │                            │
│   • Discards progress; reverts to initial parameters upon remount.     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Architectural Realities:
1. **Public Sealed Contract**: [DurableAnimationController] is a `sealed class` (not an abstract class extending Flutter's [AnimationController]). It provides the complete set of standard animation kinematics methods (`forward`, `reverse`, `toggle`, `animateTo`, `animateBack`, `repeat`, `fling`, `animateWith`, `animateBackWith`, `stop`, `reset`) and state getters (`value`, `velocity`, `status`, `duration`, `reverseDuration`, `isAnimating`, `isDismissed`, `isCompleted`, `isForwardOrCompleted`, `isActive`, `isDormant`).
2. **View Isolation**: [DurableAnimationController] deliberately **does not** expose `.view` or `.drive(...)` at its root level. Exposing raw [Animation] views on store-held controllers creates zombie listener leaks when widgets unmount.
3. **Element-Scoped View**: When widgets mount via `composed.animate`, the builder receives a [ScopedAnimationController] (`_ScopedDurableAnimationControllerProxy`) which exposes `.view` (`Animation<double>`) and `.drive(...)` (`Animation<U>`). Standard Flutter transition widgets ([SlideTransition], [FadeTransition], [RotationTransition], [AnimatedBuilder]) consume this scoped view.
4. **Testing & Reactive Extensions**:
   - `DurableAnimationTestingExtension`: Exposes `@visibleForTesting` hooks (`view`, `drive`, `attachVsync`, `detachVsync`, `wake`, `hibernate`) for headless test suites.
   - `DurableAnimationControllerObserveExtension`: Provides `.observe()` to stream animated progress as a reactive [What<double>] node.

---

## 3. The Inversion-of-Control (IoC) Dormancy Model & Redundancy of Disposal

In standard Flutter architecture, [AnimationController] requires explicit lifecycle ownership in [StatefulWidget]:

```dart
// [Anti-Pattern] Standard Flutter Disposal Ceremony
class _MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }
  @override
  void dispose() {
    _ctrl.dispose(); // Mandatory manual ceremony to avoid Ticker leaks!
    super.dispose();
  }
}
```

In `what_flutter`, [DurableAnimationController] operates on an **Inversion of Control (IoC) Dormancy Model**:

1. **Framework-Governed Ticker Allocation**:
   Physical [Ticker] instances are allocated strictly on-demand when mounted via `composed.animate` (backed by `_DurableVsyncSocketElementMixin`) and are synchronously torn down at the engine level upon element unmount.
2. **The "Disposal Ceremony" Anti-Pattern**:
   Unless raw external listeners are manually registered outside the reactive pipeline, calling `dispose()` manually is **strictly redundant**. Introducing artificial `StatefulWidget` wrappers, store teardown hooks, or manual `.stop()` cascades solely to invoke `dispose()` violates separation of concerns and creates **premature invalidation bugs** (destroying timeline continuity while dormant navigation stacks or sibling proxies still reference the state).

**Rule of Thumb:** Let the reactive pipeline govern ticker allocation. Never introduce lifecycle ceremony for resources the framework already reclaims.

---

## 4. Multi-Holder Single VSYNC Authority & Dynamic Resync Handover

### 4.1 The Orchestration Paradigm: Conductor & Performers
When coordinating multiple visual elements across a subtree, a single [DurableAnimationController] acts as a master **Conductor**, driving a unified timeline:
- **Single VSYNC Socket**: The conductor requires exactly one authoritative physical VSYNC clock driving its active engine.
- **Multiple Reactive Observers**: Individual child widgets observe the controller's reactive state or consume derived interval sub-timelines via [ScopedAnimationController].
- **Multi-Holder Priority Stack**: Multiple widgets across the tree can register as VSYNC holders via `_attachVsync(vsync)`. The controller maintains an internal `_activeVsyncs` list.

### 4.2 Dynamic Resync Handover
When multiple widgets share a controller, the controller handles holder detachments without dropping animation frames:

```text
[ Controller Active: Ticking with Holder A ]
       │
       ▼ (Widget A unmounts / navigates away)
[ Detach VSync A ] ──► Inspects candidate pool: Holder B is active!
       │
       ▼ (Resync Handover)
[ _delegate._handoverVsync(Holder B) ] ──► Calls engine.resync(Holder B)
       │
       ▼
[ Controller continues ticking at 60/120 FPS uninterrupted! ]
```

1. If the primary driving holder detaches (Widget A unmounts), `_detachVsync` inspects `_activeVsyncs`.
2. It selects the next active candidate (Widget B) and executes `_delegate._handoverVsync(candidate)`, which invokes `_engine.resync(candidate)` on the underlying Flutter engine.
3. The animation continues running smoothly without restarting, jumping, or throwing `TickerCanceled`.
4. Only when the **last** VSYNC holder detaches (`_activeVsyncs.isEmpty`) does the controller deactivate its engine and enter dormant state (`_deactivateEngine()`).

### 4.3 The Heterogeneous `TickerMode` Anti-Pattern
A frequent architectural question in multi-widget coordination is:
> *"Can multiple child widgets share a single controller if one child is muted via `TickerMode(enabled: false)`?"*

From first principles, **a single controller cannot simultaneously run and not run**:
1. **Clock Indivisibility**: A single controller possesses one unified progress value ($x \in [0.0, 1.0]$) advancing along a single physical VSYNC timeline. Allowing one branch of the tree to mute the shared clock while another demands active frames introduces a fundamental logical contradiction.
2. **Orchestration vs. Independence**:
   - **Orchestration (Shared Controller)**: Elements participate in a shared, harmonious performance. Their visibility and clock lifecycle are bound to the orchestration host.
   - **Independent Lifecycles (Separate Controllers)**: If Widget B must pause its animation clock when hidden (e.g., inside an inactive tab or offstage) while Widget A continues animating, they **do not share a timeline**. They represent independent state machines and **MUST** own separate [DurableAnimationController] instances.
3. **Architectural Invariant**: Never multiplex conflicting [TickerMode] states across children of a shared controller. If a subtree requires independent muting or lifecycle governance, allocate an independent controller.

---

## 5. Kinematics, Durability Policies, and Mathematical Formulations

### 5.1 `DurabilityPolicy.resume`: State-Preserving Freeze
Used for drawers, accordion panels, dropdowns, and interactive expanding cards where progress must freeze and resume seamlessly upon return:

1. **Dormant Staging (`_StagedMotion`)**: When `vsync` detaches, the active Ticker engine tears down, freezing progress (`value`), velocity, and parameters into immutable [_StagedMotion] objects.
2. **$C^1$ Continuity Restoration via `_TimeOffsetSimulation`**:
   - Injects the prior elapsed duration offset ($t_{\text{offset}} = \text{lastElapsedDuration}$) upon remount.
   - Time domain mapping:
     $$t' = t + t_{\text{offset}}$$
   - Position and velocity preservation:
     $$x'(t) = S.x(t + t_{\text{offset}}), \quad \dot{x}'(t) = S.\dot{x}(t + t_{\text{offset}})$$
   - With position and velocity $C^1$ continuous, remounted motions resume without visual snapping or pop artifacts.

### 5.2 `DurabilityPolicy.catchUp`: Wall-Clock Time Compensation
Used for continuous radar sweeps, loading spinners, timers, and telemetry feeds that must stay synchronized with **real-world elapsed time**:

1. **Deactivation Timestamp**: On deactivation, the dormant delegate captures $t_{\text{deactivated}} = \text{clock}()$.
2. **Pure Projection During Dormancy**:
   Any read to `.value` or `.status` while dormant calculates projected progress across $\Delta t = \text{clock}() - t_{\text{deactivated}}$ as a **pure calculation**:
   - Mutates zero internal state.
   - Emits zero listener notifications, ensuring zero `setState()` assertions during build-phase reads.
3. **Kinematic Projections by Motion Mode**:
   - **Linear Bounded Motion (`forward` / `reverse`)**:
     $$\Delta p = \frac{\Delta t}{T} \cdot (x_{\text{upper}} - x_{\text{lower}})$$
     $$x_{\text{forward}} = \min(x_{\text{upper}}, x_0 + \Delta p), \quad x_{\text{reverse}} = \max(x_{\text{lower}}, x_0 - \Delta p)$$
   - **Standard Looping Repeat (`repeat` with `reverse: false`)**:
     $$\text{loops} = \frac{\Delta t}{T_{\text{period}}}, \quad \phi = (\text{loops} - \lfloor\text{loops}\rfloor) \cdot \Delta x$$
     $$x_{\text{loop}} = x_{\text{min}} + ((x_0 - x_{\text{min}} + \phi) \pmod{\Delta x})$$
   - **Ping-Pong Alternating Repeat (`repeat` with `reverse: true`, $T_{\text{cycle}} = 2 T_{\text{period}}$)**:
     Evaluates phase in the bidirectional coordinate space $[0, 2\Delta x]$, accurately determining whether the motion landed in forward or reverse phase, and settling on exact odd/even boundary targets when `repeatCount` is reached.
   - **Physics & Fling (`simulation` / `fling`)**:
     $$t_{\text{total}} = t_{\text{accumulated}} + \Delta t$$
     $$x_{\text{sim}} = \text{clamp}(S.x(t_{\text{total}}), x_{\text{lower}}, x_{\text{upper}})$$
     If $S.\text{isDone}(t_{\text{total}})$, transitions cleanly to completed/dismissed status.
4. **Waking Compensation**:
   Upon remounting, `applyElapsedCompensation(\Delta t)` updates progress and staged motion, instantiating the active engine at the exact real-world coordinates.

### 5.3 `DurabilityPolicy.reset`: Clean-Slate Re-Entry
Used for transient entrance effects, splash banners, or dialog popups:
- Discards in-flight progress upon deactivation.
- Reverts `value`, `duration`, and `reverseDuration` to initial constructor parameters (`_initialValue ?? lowerBound`, `_initialDuration`, `_initialReverseDuration`).
- Resets staged motion to `_StagedMotion.idle()`, ensuring the animation restarts fresh upon re-entry.

### 5.4 Numerical Central Finite Difference (`_CurvedInterpolationSimulation`)
During interrupted curved motions ([Curves]), central finite differences evaluate instantaneous velocity:
$$\dot{x}(t) = \frac{d x}{d t} = (x_{\text{end}} - x_{\text{begin}}) \cdot \frac{C(\tau + \epsilon) - C(\tau - \epsilon)}{2 \epsilon \cdot T}$$
where $\epsilon = 0.001$, $\tau = \text{clamp}(t / T, 0.0, 1.0)$, and $T = \text{duration in seconds}$.

---

## 6. Staged Motion Archetypes (`_StagedMotionMode`)

When animation commands fire during dormant states, `_StagedMotionMode` organizes them into 9 archetypes (1 idle + 8 active motions):

| Mode (`_StagedMotionMode`) | Preserved State | Restoration Behavior on Reconnection |
| :--- | :--- | :--- |
| **`idle`** | None | Remains dormant at current coordinate |
| **`forward`** | `targetFromValue`, `duration` | Resumes progress towards `upperBound` |
| **`reverse`** | `targetFromValue`, `reverseDuration` | Resumes progress towards `lowerBound` |
| **`repeat`** | `repeatMin`, `repeatMax`, `repeatReverse`, `repeatPeriod`, `repeatCount`, `wasReversePhase` | Preserves repeat period, loop count, and ping-pong phase |
| **`animateTo`** | `targetValue`, `targetDuration`, `targetCurve`, `simulation`, `elapsedDuration` | Resumes curve interpolation towards target coordinate |
| **`animateBack`** | `targetValue`, `targetDuration`, `targetCurve`, `simulation`, `elapsedDuration` | Resumes curve interpolation backwards towards target coordinate |
| **`fling`** | `flingVelocity`, `springDescription`, `simulation`, `wasReversePhase`, `elapsedDuration` | Resumes spring simulation using `_TimeOffsetSimulation` |
| **`simulation`** | Original [Simulation], `elapsedDuration` | Offsets physics timeline via `_TimeOffsetSimulation` |
| **`simulationBack`** | Original [Simulation], `elapsedDuration` | Offsets physics timeline in reverse status |

### Dormant Future Completion Contract
When any motion command (`forward()`, `reverse()`, `animateTo()`, `repeat()`, `fling()`, `animateWith()`) is invoked while dormant (no active VSYNC attached), the controller stages the motion intent and **immediately returns a completed [TickerFuture]** (`TickerFuture.complete()`). This guarantees:
1. Zero orphaned async suspension leaks (no pending futures hanging while widgets are unmounted).
2. Exact deterministic motion resumption when a VSYNC provider re-attaches.

---

## 7. Element Proxy & Listener Lifecycle Isolation (`_ScopedDurableAnimationControllerProxy`)

When multiple widgets observe a shared controller via `composed.animate`, internal proxy wrappers isolate listeners to prevent unmounted widgets from affecting the shared controller or clearing sibling registrations.

```text
[ DurableAnimationController (Store / Conductor) ]
          │
          ├─► Scoped Proxy A (Widget 1) ──► Listens & Animates
          │        │
          │        ▼ (Widget 1 Unmounts -> Proxy A cleans up & Disposes!)
          │        Proxy A only detaches its own listeners.
          │
          └─► Scoped Proxy B (Widget 2) ──► Continues smoothly without interruption!
```

### Strict Fail-Fast View Guard
To eliminate zombie lifecycle leaks, the proxy and its view enforce strict assertions:
1. **Proxy Disposal Guard (`_assertNotDisposed`)**: Any attempt to dispatch motion directives (`forward`, `animateTo`, `stop`, `reset`) on a disposed proxy throws an assertion.
2. **View Listener Guard (`didRegisterListener`)**: In `_ScopedProxyAnimationView`, attempting to register listeners after proxy disposal asserts:
   ```dart
   assert(!_isDisposed, 'Cannot attach listeners to a disposed ScopedProxyAnimationView.');
   ```
   This prevents derived animations ([CurvedAnimation], [Tween.animate]) created outside the active widget lifecycle from leaking memory.

---

## 8. Production Code Patterns

### 8.1 Pairing Declarative CatchUp with `composed.animate`
```dart
class RadarScannerView extends StatelessWidget {
  const RadarScannerView({super.key, required this.controller});
  final DurableAnimationController controller;

  @override
  Widget build(BuildContext context) {
    return composed.animate(
      controller,
      (context, via, ctrl) => RotationTransition(
        turns: ctrl.view,
        child: const RadarSweepImage(),
      ),
      onActivate: (ctrl) => ctrl.repeat(),
    );
  }
}
```

### 8.2 Surgical Inline Motion with Static Subtree Memoization (`composed.animate.child`)
```dart
class ExpandableCard extends StatelessWidget {
  const ExpandableCard({super.key, required this.controller});
  final DurableAnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeavyCardHeader(), // Rebuild count: 0
        // 60/120fps frame ticking is isolated strictly to this SizeTransition;
        // child subtree is memoized and never rebuilt on animation ticks.
        composed.animate.child(
          controller,
          (context, via, ctrl, child) => SizeTransition(
            sizeFactor: ctrl.view,
            child: child,
          ),
          child: const HeavyCardBodyContent(),
        ),
      ],
    );
  }
}
```

### 8.3 Coordinated Multi-Element Staggered Orchestration
```dart
class StaggeredDialog extends StatelessWidget {
  const StaggeredDialog({super.key, required this.controller});
  final DurableAnimationController controller;

  @override
  Widget build(BuildContext context) {
    // Single VSYNC host at parent; child transitions consume interval sub-timelines via ScopedAnimationController
    return composed.animate(
      controller,
      (context, via, ctrl) {
        final fadeAnimation = CurvedAnimation(
          parent: ctrl.view,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        );
        final scaleAnimation = CurvedAnimation(
          parent: ctrl.view,
          curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: const Card(child: Text('Dialog Content')),
          ),
        );
      },
    );
  }
}
```

### 8.4 Passive Reactive Observation via `controller.observe()`
```dart
class AnimationTelemetryWidget extends StatelessWidget {
  const AnimationTelemetryWidget({super.key, required this.controller});
  final DurableAnimationController controller;

  @override
  Widget build(BuildContext context) {
    // Passively observes animated progress as a What<double> node.
    // Does NOT generate VSYNC ticks; passively receives updates from active VSYNC hosts.
    final progressWhat = controller.observe();

    return composed(
      (context, via) => Text('Progress: ${(via(progressWhat) * 100).toStringAsFixed(1)}%'),
    );
  }
}
```

---

## 9. Core Engineering Invariants

1. **Zero-Leak Ticker & IoC Dormancy Invariant**:
   Physical [Ticker] instances are allocated strictly on-demand by mounted elements and synchronously reclaimed upon unmount. Calling `dispose()` manually on store controllers is strictly redundant.
2. **Multi-Holder Resync Handover Invariant**:
   When multiple widgets share a controller, detaching the primary VSYNC holder seamlessly hands over the active engine via `_engine.resync` to the next active candidate in `_activeVsyncs` without interrupting playback or dropping frames.
3. **Wall-Clock Monotonicity & Pure Projection Invariant**:
   Under [DurabilityPolicy.catchUp], elapsed dormant duration ($\Delta t$) monotonically compensates progress. Dormant property reads (`value`, `status`) are pure mathematical projections that emit zero listener notifications and cause zero `setState` re-entrancy issues.
4. **$C^1$ Continuity & Time-Offset Invariant**:
   Motions restored via [_TimeOffsetSimulation] preserve both position $x(t)$ and instantaneous velocity $\dot{x}(t)$ profiles across unmount/remount cycles, eliminating visual jumps and clipping artifacts.
5. **Dormant Future Completion Invariant**:
   Motion commands dispatched during dormancy immediately return `TickerFuture.complete()`, staging motion parameters without creating uncollected async suspension leaks.
6. **Scoped Proxy Isolation Invariant**:
   Each `composed.animate` boundary operates through an isolated `_ScopedDurableAnimationControllerProxy`. Unmounting an element disposes only its local proxy, leaving sibling observers and the parent controller completely unaffected.
7. **Single VSYNC Authority Invariant**:
   A [DurableAnimationController] governs a single, continuous physical timeline. Subtrees requiring divergent [TickerMode] muting must be decomposed into independent controller instances.

---

## 10. Engineering Conclusions

The **Durable Animation Architecture** in `what_flutter` elevates UI animation from an error-prone, widget-bound imperative chore into a deterministic, state-durable reactive subsystem:
- By separating the public [DurableAnimationController] contract from the element-scoped [ScopedAnimationController] view, it completely eliminates zombie listener leaks.
- By leveraging the **Inversion-of-Control Dormancy Model**, it reclaims physical ticker resources automatically upon unmount without requiring artificial disposal ceremony.
- By providing **Resync Handover** across multiple VSYNC holders, it enables seamless multi-widget coordination without interrupted timelines.
- By providing mathematically precise **Wall-Clock Compensation** and **$C^1$ Continuous Simulations**, it guarantees that real-world continuity is preserved across tab drops, navigation routes, and application backgrounding.
