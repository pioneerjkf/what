// Canonical lint cases for `avoid_untracked_what_read`.
// Grammar: see what_lints/test/harness/lint_harness.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

final counter = WhatController(0);
final count = counter.what;
final other = WhatController(1).what;

// =============================================================================
// BAD
// =============================================================================

// #case avoid_untracked_what_read/bad/data-in-computed
final badComputed = computed((via) {
  final factor = via(other);
  // expect_lint: avoid_untracked_what_read
  return count.peek * factor;
});

// #case avoid_untracked_what_read/bad/mixed-tracked-and-untracked
final badMixed = computed((via) {
  // expect_lint: avoid_untracked_what_read
  return via(count) + other.peek;
});

// #case avoid_untracked_what_read/bad/method-read-in-computed
final badMethod = computed((via) {
  final factor = via(other);
  // expect_lint: avoid_untracked_what_read
  return count.peekState.dataOrElse(() => 0) * factor;
});

// #case avoid_untracked_what_read/bad/data-in-effect-via
final badEffect = Effect.via((via) {
  // expect_lint: avoid_untracked_what_read
  print(count.peek);
});

// #case avoid_untracked_what_read/bad/data-in-what-widget-build
final class BadCounterText extends WhatWidget {
  const BadCounterText({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    // expect_lint: avoid_untracked_what_read
    return Text('${count.peek}');
  }
}

// #case avoid_untracked_what_read/bad/data-in-composed
Widget badComposed() => composed((context, via) {
      // expect_lint: avoid_untracked_what_read
      return Text('${count.peek}');
    });

// =============================================================================
// GOOD
// =============================================================================

// #case avoid_untracked_what_read/good/tracked-via
final goodComputed = computed((via) => via(count) + via(other));

// #case avoid_untracked_what_read/good/raw-read-outside-scope
int goodRawRead() => count.peek;

// #case avoid_untracked_what_read/good/raw-read-in-event-callback
final class GoodCounterButton extends WhatWidget {
  const GoodCounterButton({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    return TextButton(
      onPressed: () => print(count.peek),
      child: Text('${via(count)}'),
    );
  }
}

// #case avoid_untracked_what_read/good/regression-P1-snapshot-variable-after-via
final goodSnapshotVar = computed((via) {
  final snap = via.state(count).snapshot;
  return snap.dataOrElse(() => 0);
});

// #case avoid_untracked_what_read/good/regression-P2-snapshot-match-after-via
final goodSnapshotMatch = computed((via) => via.state(count).snapshot.match(
      data: (v) => v,
      empty: () => 0,
      error: (e, s) => -1,
    ));

// #case avoid_untracked_what_read/good/regression-P3-aliased-via-result
final goodAlias = computed((via) {
  final tracked = via.state(count);
  return tracked.data;
});

// #case avoid_untracked_what_read/good/regression-P4-renamed-via-parameter
final goodRenamed = computed((WhatVia v) => v(count));

// #case avoid_untracked_what_read/good/regression-P5-guard-with-what-guard
final goodGuard = computed(
  (via) => via(count),
  guard: (via) => (via(other) > 0).guarded('otherNonPositive'),
);

// #case avoid_untracked_what_read/good/regression-P10-manifest-effect-targets
final goodManifestEffect = Effect([count], () => print(count.peek));

// #case avoid_untracked_what_read/good/regression-P12-terminal-effect-in-build
final class GoodTerminalEffectInBuild extends WhatWidget {
  const GoodTerminalEffectInBuild({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    via.tether(count.effect(() {
      if (count.peek > 0) {
        print('count=${count.peek}');
      }
    }));
    return const SizedBox();
  }
}

// #case avoid_untracked_what_read/good/regression-P13-tracked-state-read-in-closure
final class GoodTrackedStateReadInClosure extends WhatWidget {
  const GoodTrackedStateReadInClosure({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final state = via.state(count);
    return state.match(
      data: (v) => Text('Count: $v'),
      empty: () => Text('Empty (${state.emptyReason})'),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
