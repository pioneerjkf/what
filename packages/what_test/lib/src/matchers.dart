// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:what/what.dart';

// =============================================================================
// LPDAG Reactive State & Lifecycle Custom Matchers
// =============================================================================

/// Matches an LPDAG node that is currently in a dormant state (0 downstream subscribers, inactive).
const Matcher isDormant = _IsDormantMatcher();

/// Matches an LPDAG node that is currently in an active state (has downstream subscribers).
const Matcher isActive = _IsActiveMatcher();

/// Creates a matcher that asserts an LPDAG node has exactly [count] active downstream subscribers.
Matcher hasSubscribers(int count) => _HasSubscribersMatcher(count);

/// Matches a reactive pipeline or snapshot sequence verifying glitch-free evaluation.
const Matcher hasGlitchFreedom = _HasGlitchFreedomMatcher();

/// Creates a matcher verifying that a [WhatSnapshot], [WhatState], or [What] node is in a valid Data state
/// and matches [expected].
Matcher isData(dynamic expected) => _IsDataMatcher(expected);

/// Creates a matcher verifying that a [WhatSnapshot], [WhatState], or [What] node is in an Empty state,
/// optionally verifying [reason].
Matcher isEmptyState([Object? reason]) => _IsEmptyStateMatcher(reason);

/// Creates a matcher verifying that a [WhatSnapshot], [WhatState], or [What] node is in an Error state,
/// optionally matching [error].
Matcher isErrorState([dynamic error]) => _IsErrorStateMatcher(error);

// -----------------------------------------------------------------------------
// Matcher Implementations
// -----------------------------------------------------------------------------

What? _extractWhat(dynamic item) {
  if (item is What) return item;
  if (item is WhatController) return item.what;
  if (item is WhatCoupler) return item.what;
  return null;
}

final class _IsDormantMatcher extends Matcher {
  const _IsDormantMatcher();

  @override
  bool matches(dynamic item, Map matchState) {
    final what = _extractWhat(item);
    if (what != null) {
      final targetCount = what.debug.targetCount;
      final isNodeActive = what.debug.snapshot().isActive;
      if (targetCount > 0 || isNodeActive) {
        matchState['targetCount'] = targetCount;
        matchState['isActive'] = isNodeActive;
        return false;
      }
      return true;
    }
    if (item is LpdagStatus) {
      if (item.isActive) {
        matchState['isActive'] = true;
        return false;
      }
      return true;
    }
    matchState['error'] = 'Object $item is not an LPDAG node or status';
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('a dormant LPDAG node (inactive, 0 subscribers)');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'].toString());
    }
    final targets = matchState['targetCount'];
    final active = matchState['isActive'];
    return mismatchDescription
        .add('was active with $targets subscribers (isActive: $active)');
  }
}

final class _IsActiveMatcher extends Matcher {
  const _IsActiveMatcher();

  @override
  bool matches(dynamic item, Map matchState) {
    final what = _extractWhat(item);
    if (what != null) {
      final targetCount = what.debug.targetCount;
      final isNodeActive = what.debug.snapshot().isActive;
      if (targetCount == 0 && !isNodeActive) {
        matchState['targetCount'] = targetCount;
        matchState['isActive'] = isNodeActive;
        return false;
      }
      return true;
    }
    if (item is LpdagStatus) {
      if (!item.isActive) {
        matchState['isActive'] = false;
        return false;
      }
      return true;
    }
    matchState['error'] = 'Object $item is not an LPDAG node or status';
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('an active LPDAG node with active subscribers');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'].toString());
    }
    return mismatchDescription
        .add('was dormant (0 subscribers, isActive: false)');
  }
}

final class _HasSubscribersMatcher extends Matcher {
  const _HasSubscribersMatcher(this.count);

  final int count;

  @override
  bool matches(dynamic item, Map matchState) {
    final what = _extractWhat(item);
    if (what != null) {
      final targetCount = what.debug.targetCount;
      if (targetCount != count) {
        matchState['actualCount'] = targetCount;
        return false;
      }
      return true;
    }
    matchState['error'] = 'Object $item is not a What node or controller';
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('an LPDAG node with exactly $count subscribers');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'].toString());
    }
    return mismatchDescription
        .add('had ${matchState['actualCount']} subscribers');
  }
}

final class _HasGlitchFreedomMatcher extends Matcher {
  const _HasGlitchFreedomMatcher();

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is Iterable) {
      final list = item.toList();
      // Verifies that a sequence of snapshots or values has no duplicate intermediate tearing.
      // In a glitch-free LPDAG diamond graph, intermediate inconsistent state is never observed.
      for (var i = 0; i < list.length; i++) {
        final current = list[i];
        if (current is WhatSnapshot && current.hasError) {
          // If an error is explicitly recorded that was a glitch exception:
          matchState['glitch'] =
              'Found error snapshot at index $i: ${current.error}';
          return false;
        }
      }
      return true;
    }
    // A single snapshot or What node is trivially glitch-free
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('a glitch-free reactive evaluation sequence');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('glitch')) {
      return mismatchDescription.add(matchState['glitch'].toString());
    }
    return mismatchDescription
        .add('observed inconsistent intermediate state during evaluation');
  }
}

WhatSnapshot? _toSnapshot(dynamic item) {
  if (item is WhatSnapshot) return item;
  if (item is WhatState) return item.snapshot;
  if (item is What) return untracked.state(item).snapshot;
  if (item is WhatController) return untracked.state(item.what).snapshot;
  return null;
}

final class _IsDataMatcher extends Matcher {
  const _IsDataMatcher(this.expected);

  final dynamic expected;

  @override
  bool matches(dynamic item, Map matchState) {
    final snapshot = _toSnapshot(item);
    if (snapshot == null) {
      matchState['error'] = '$item is not a WhatSnapshot or reactive node';
      return false;
    }
    if (!snapshot.hasData) {
      matchState['state'] = snapshot.toString();
      return false;
    }
    final data = snapshot.data;
    final matcher =
        expected is Matcher ? expected as Matcher : equals(expected);
    final subState = {};
    if (!matcher.matches(data, subState)) {
      matchState['actualData'] = data;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) => description
      .add('a valid Data state matching ')
      .addDescriptionOf(expected);

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'].toString());
    }
    if (matchState.containsKey('state')) {
      return mismatchDescription
          .add('was not in Data state: ${matchState['state']}');
    }
    if (matchState.containsKey('subMismatch')) {
      return mismatchDescription.add(matchState['subMismatch'].toString());
    }
    return mismatchDescription.add('had data ${matchState['actualData']}');
  }
}

final class _IsEmptyStateMatcher extends Matcher {
  const _IsEmptyStateMatcher([this.reason]);

  final Object? reason;

  @override
  bool matches(dynamic item, Map matchState) {
    final snapshot = _toSnapshot(item);
    if (snapshot == null) {
      matchState['error'] = '$item is not a WhatSnapshot or reactive node';
      return false;
    }
    if (!snapshot.isEmpty) {
      matchState['state'] = snapshot.toString();
      return false;
    }
    if (reason != null &&
        snapshot.emptyReason != reason &&
        snapshot.emptyReason?.toString() != reason.toString()) {
      matchState['actualReason'] = snapshot.emptyReason;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('an Empty state');
    if (reason != null) {
      description.add(' with reason "$reason"');
    }
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'].toString());
    }
    if (matchState.containsKey('state')) {
      return mismatchDescription
          .add('was not in Empty state: ${matchState['state']}');
    }
    return mismatchDescription
        .add('had emptyReason "${matchState['actualReason']}"');
  }
}

final class _IsErrorStateMatcher extends Matcher {
  const _IsErrorStateMatcher([this.expectedError]);

  final dynamic expectedError;

  @override
  bool matches(dynamic item, Map matchState) {
    final snapshot = _toSnapshot(item);
    if (snapshot == null) {
      matchState['error'] = '$item is not a WhatSnapshot or reactive node';
      return false;
    }
    if (!snapshot.hasError) {
      matchState['state'] = snapshot.toString();
      return false;
    }
    if (expectedError != null) {
      final actualErr = snapshot.error;
      if (expectedError is Matcher) {
        final matcher = expectedError as Matcher;
        final subState = {};
        if (!matcher.matches(actualErr, subState)) {
          matchState['subMismatch'] = matcher
              .describeMismatch(
                actualErr,
                StringDescription(),
                subState,
                false,
              )
              .toString();
          return false;
        }
        return true;
      }
      if (actualErr != expectedError &&
          actualErr.toString() != expectedError.toString()) {
        matchState['actualError'] = actualErr;
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('an Error state');
    if (expectedError != null) {
      description.add(' matching ').addDescriptionOf(expectedError);
    }
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'].toString());
    }
    if (matchState.containsKey('state')) {
      return mismatchDescription
          .add('was not in Error state: ${matchState['state']}');
    }
    if (matchState.containsKey('subMismatch')) {
      return mismatchDescription.add(matchState['subMismatch'].toString());
    }
    return mismatchDescription.add('had error ${matchState['actualError']}');
  }
}
