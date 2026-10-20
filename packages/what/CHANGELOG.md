## 0.2.0

- **Breaking Change (Architecture)**: Removed `peek` and `peekState` getters from the public `What<T>` interface. `What<T>` is now a strictly opaque DAG node handle with zero public read getters. Untracked reads are now explicitly performed via `untracked(what)` and `untracked.state(what)`, establishing a clean architectural symmetry between tracked (`via`) and untracked reads.

## 0.1.0

- Initial release of `what` on pub.dev.
