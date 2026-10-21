## 0.3.0

- **Dependencies**: Bumped `what` and `what_extensions` dependencies to `^0.3.0`.
- **Async Widgets**: Modernized `WhatAsyncBuilder` and async branch routing to exhaustive switch expressions over `WhatPhase`.
- **Breaking Change**: Purged legacy match extensions in widget rendering in favor of Dart 3 pattern matching on `state.phase`.

## 0.2.0

- **Dependencies**: Bumped `what` dependency to `^0.2.0`.
- **Architecture**: Aligned with the opaque `What<T>` architecture and symmetrical `untracked(what)` / `untracked.state(what)` functors.

## 0.1.0

- Initial release of `what_flutter` on pub.dev.
