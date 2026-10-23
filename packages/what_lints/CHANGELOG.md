## 0.3.1

- **Deprecation & Ecosystem Migration**: Marked package as discontinued in favor of [`blooming_lints`](https://pub.dev/packages/blooming_lints).
- **Documentation**: Updated README with migration guide.

## 0.3.0

- **Type Checker**: Added `phase` property recognition to pipeline read AST analyzer.
- **AST Cleanup**: Completely removed purged `match()`, `matchOrElse()`, and `matchOrNull()` methods from type checker and quick fixes.
- **Quality & Pana**: Resolved flow control brace formatting and hardened dependency bounds for `custom_lint_builder`.

## 0.2.0

- **Refactor**: Removed deprecated `peek` and `peekState` checks from AST type checker and quick fixes following the opaque `What<T>` architecture migration.

## 0.1.0

- Initial release of `what_lints` on pub.dev.
