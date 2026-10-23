## 0.3.1

- **Deprecation & Ecosystem Migration**: Marked package as discontinued in favor of [`blooming`](https://pub.dev/packages/blooming).
- **Documentation**: Updated README with comprehensive migration guide and rebranding details.

## 0.3.0

- **Breaking Change (Architecture)**: Introduced `WhatPhase` 3-state operational enum (`valid`, `empty`, `error`) and exposed `phase` getter across `WhatState<T>` and `WhatSnapshot<T>`.
- **Breaking Change (API Cleanup)**: Completely purged legacy `WhatStateMatchExtension` (`match()`, `matchOrElse()`, `matchOrNull()`) in favor of idiomatic Dart 3 exhaustive switch expressions over `state.phase`.
- **Feature (Collections)**: Added `wherePhase(WhatPhase)` and optimized collection extensions with fast `switch (phase)` jump tables.
- **Performance & Observability**: Refactored `WhatDebugSnapshot` with unified `WhatPhase` representation for streamlined devtools inspection.

## 0.2.0

- **Breaking Change (Architecture)**: Removed `peek` and `peekState` getters from the public `What<T>` interface. `What<T>` is now a strictly opaque DAG node handle with zero public read getters. Untracked reads are now explicitly performed via `untracked(what)` and `untracked.state(what)`, establishing a clean architectural symmetry between tracked (`via`) and untracked reads.

## 0.1.0

- Initial release of `what` on pub.dev.
