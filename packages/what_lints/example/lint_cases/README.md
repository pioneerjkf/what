# what_lints canonical lint cases

`what_lints` behavior is pinned by two corpora. Both are fully resolved
against the real `what` / `what_flutter` packages, and every registered rule
runs on them through its actual `run()` pipeline in
[`test/harness/`](../../test/harness/).

| Corpus | Audience | Content |
|---|---|---|
| [`../lib/main.dart`](../lib/main.dart) | pub.dev Example tab, humans | A guided tour with exactly one `tour/<rule>/bad` and one `tour/<rule>/good` case per rule. Completeness is enforced. |
| `lint_cases/` (here) | Maintainers, CI | Exhaustive edge cases, cross-rule interactions, and regression cases. |

```sh
# from packages/what_lints
dart test test/harness/
```

## Grammar

```dart
// #case <rule>/<bad|good>/<slug>
final doubled = computed((via) {
  final factor = via(other);
  // expect_lint: avoid_untracked_what_read
  return counter.peek * factor;   // the diagnostic must start on this line
});
```

| Marker | Meaning |
|---|---|
| `// #case <id>` | Opens a case region that lasts until the next marker. Each case becomes one test. |
| `// expect_lint: a, b` | Rules `a` and `b` must report on the **next line**. Same semantics as `custom_lint`. |

## Contract enforced by the harness

- **Exact match per case**: an unexpected diagnostic is a false positive. A missing one is a false negative.
- **All rules run on every file**, so cross-rule noise is caught as well.
- Every file must **compile without analyzer errors**.
- Every registered rule must have **at least one `bad` case**.
- `expect_lint` must name a registered rule and sit inside a `#case`.
- Case ids must be unique.

## Authoring guidelines

- **One concern per case.** A `bad` case should trigger exactly the rule under test (see `bad/data-in-computed`).
- **Fixing a reported bug:** add a `good/regression-<id>-...` (false positive) or `bad/...` (false negative) case **first**, watch it fail, then fix the rule.
- **Use real APIs only.** These files are what users would actually write.
