<h1 align="center">What Lints</h1>

<p align="center">
  <strong>Official High-Performance Static Analysis &amp; Self-Healing Lint Rules for What and What Flutter</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/what_lints"><img src="https://img.shields.io/pub/v/what_lints.svg?style=flat-square" alt="Pub Version" /></a>
  <a href="https://pub.dev/packages/what_lints/score"><img src="https://img.shields.io/pub/points/what_lints.svg?style=flat-square" alt="Pub Points" /></a>
  <a href="https://github.com/pioneerjkf/what/blob/main/packages/what_lints/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square" alt="License" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.6+-0175C2.svg?style=flat-square&logo=dart" alt="Dart SDK" /></a>
</p>

> [!WARNING]
> ### 🌸 Discontinued & Succeeded by [blooming_lints](https://pub.dev/packages/blooming_lints)
>
> **Notice of Package Migration & Rebranding**
>
> To eliminate long-term cognitive ambiguity caused by the interrogative naming convention (`What`) and provide a clearer, more expressive architectural identity, `package:what_lints` has been **officially discontinued and succeeded by [`package:blooming_lints`](https://pub.dev/packages/blooming_lints)**.
>
> Active development and new lint diagnostics have fully transitioned to the **Blooming** repository.
>
> * 🔗 **New GitHub Repository**: [github.com/pioneerjkf/blooming](https://github.com/pioneerjkf/blooming)
> * 📦 **Replacement Package**: [`blooming_lints`](https://pub.dev/packages/blooming_lints)
>
> #### Migration Guide
> Update your `pubspec.yaml`:
> ```diff
>  dev_dependencies:
> -  what_lints: ^0.3.0
> +  blooming_lints: ^1.0.0
> ```
> Update your `analysis_options.yaml`:
> ```diff
>  plugins:
> -  - what_lints
> +  - blooming_lints
> ```
> *We sincerely thank you for using and supporting What Lints!*

---


## Features & Rules

`what_lints` provides strict, real-time diagnostic checks and self-healing guidance for both human developers and AI coding agents (Antigravity, Cursor, Claude Code, Copilot).

Rules are logically categorized into **Core Reactive Invariants** (pure Dart, framework-agnostic) and **Flutter Integration Guards** (`what_flutter` UI & lifecycle):

### 1. Core Reactive Invariants (Pure Dart)

Rules governing the core reactive LPDAG, transactional state boundaries, and `WhatVia` dependency manifests. Fully effective in pure Dart (CLI, backend, web, package) as well as Flutter:

| Lint Rule | Severity | Description |
| :--- | :---: | :--- |
| **`avoid_escaping_via`** | Error | Prohibits calling `via()` across asynchronous gaps (`await`), inside async timers, or deferred inside event callbacks to prevent temporal inconsistency and broken epochs. |
| **`avoid_catching_via_short_circuit`** | Error | Prohibits catching broad exceptions around `via()` calls inside reactive scopes to prevent intercepting What's internal short-circuit sentinel. |
| **`avoid_async_in_managed`** | Error | Prohibits passing asynchronous closures or Future/Stream return types to `managed()` to maintain pure synchronous resource lifecycle supervision. |
| **`avoid_state_writes_in_pipeline`** | Error | Prohibits writing state or mutating topology directly inside reactive pipeline evaluation or build passes. |
| **`avoid_untracked_what_read`** | Error | Prohibits reading `untracked(...)`, `untracked.state(...)`, or controller `.data` directly inside `WhatVia` scopes (`computed`, `composed`, `switched`, `WhatWidget`) without calling `via()` to prevent silent lost-reactivity bugs. |
| **`avoid_via_state_when_value_suffices`** | Info | Recommends calling `via(x)` directly instead of `via.state(x).data` when only the payload value is needed to ensure 0-alloc derivation. |
| **`avoid_unnecessary_via_scope`** | Info | Warns when a `computed` or `switched` scope declares a `via` parameter but never accesses it to track upstream dependencies. |

### 2. Flutter Integration Guards (`what_flutter`)

Rules safeguarding Flutter widget trees, element lifecycles, and rebuild optimization:

| Lint Rule | Severity | Description |
| :--- | :---: | :--- |
| **`avoid_what_creation_in_build`** | Error | Prohibits instantiating What controllers (`WhatController`), reactive pipelines (`computed`, `managed`), signals, or effects inside Flutter `build()` methods to prevent orphan state resets and memory leaks. |
| **`avoid_escaping_scoped_controller`** | Error | Prohibits escaping `ScopedAnimationController` or its `.view` outside the widget builder scope (e.g. storing in fields, outer variables, or outer collections) to prevent stale listeners and zombie lifecycle leaks. |
| **`avoid_bridging_in_build`** | Warning | Prevents calling reactive bridging methods (`.toWhat()`, `.toWhatBy()`, `.toListenable()`) inside `build()` or reactive derivation scopes to eliminate per-frame allocations. |
| **`deactivate_effect_runner`** | Warning | Requires deactivating `EffectRunner` instances held in `State` classes inside `dispose()` to prevent memory leaks. |
| **`prefer_composed_child`** | Info | Calculates AST subtree complexity to enforce strict isolation of heavy static widget subtrees and high-frequency (e.g. `observe`) animation sources from `composed` closures via `composed.child` caching or const extraction. |
| **`prefer_what_over_controller`** | Info | Recommends accepting read-only `What<T>` instead of mutable `WhatController<T>` in widget constructor parameters to preserve Producer/Consumer separation. |

---

## Installation

Add `what_lints` and `custom_lint` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
  what_lints: ^0.2.0
```

Enable the plugin in your `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

---

## License

Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
