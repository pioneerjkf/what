// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

class TickerDrivenWidget extends StatefulWidget {
  const TickerDrivenWidget({super.key});

  @override
  State<TickerDrivenWidget> createState() => _TickerDrivenWidgetState();
}

class _TickerDrivenWidgetState extends State<TickerDrivenWidget>
    with SingleTickerProviderStateMixin {
  late final tickWhat = drive(
    (elapsed) => elapsed.inMilliseconds,
    distinct: true,
  );

  @override
  Widget build(BuildContext context) {
    return composed((context, via) => Text('ElapsedMs: ${via(tickWhat)}'));
  }
}

class ErrorTrappingTickerDrivenWidget extends StatefulWidget {
  const ErrorTrappingTickerDrivenWidget({super.key});

  @override
  State<ErrorTrappingTickerDrivenWidget> createState() =>
      _ErrorTrappingTickerDrivenWidgetState();
}

class _ErrorTrappingTickerDrivenWidgetState
    extends State<ErrorTrappingTickerDrivenWidget>
    with SingleTickerProviderStateMixin {
  late final tickWhat = drive(
    (elapsed) {
      if (elapsed.inMilliseconds > 500) {
        throw StateError('Tick overflow');
      }
      return elapsed.inMilliseconds;
    },
    distinct: false,
  );

  @override
  Widget build(BuildContext context) {
    return composed((context, via) {
      final nodeState = via.state(tickWhat);
      if (nodeState.hasError) {
        return const Text('State: Error');
      }
      return Text('State: ${nodeState.data}');
    });
  }
}

void main() {
  group('Scheduler & Ticker Driving Widget Tests', () {
    testWidgets(
        '1.1 vsync.drive continuously receives frame ticks and updates UI',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TickerDrivenWidget(),
        ),
      );

      expect(find.text('ElapsedMs: 0'), findsOneWidget);

      // Advance clock by 100ms
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ElapsedMs: 100'), findsOneWidget);

      // Advance clock by another 150ms (total 250ms)
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('ElapsedMs: 250'), findsOneWidget);
    });

    testWidgets(
        '1.2 Exception inside onTick is safely trapped and transitions what to error',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ErrorTrappingTickerDrivenWidget(),
        ),
      );

      expect(find.text('State: 0'), findsOneWidget);

      // Advance clock within safe limit
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('State: 200'), findsOneWidget);

      // Advance clock past 500ms to trigger exception
      await tester.pump(const Duration(milliseconds: 400)); // total 600ms
      expect(find.text('State: Error'), findsOneWidget);
    });

    testWidgets(
        '1.3 Unmounting widget cleanly disposes ticker and stops frame subscriptions',
        (tester) async {
      final showWidgetNotifier = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: showWidgetNotifier,
            builder: (context, show, _) {
              return show ? TickerDrivenWidget() : const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(find.text('ElapsedMs: 0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ElapsedMs: 100'), findsOneWidget);

      // Unmount widget
      showWidgetNotifier.value = false;
      await tester.pump();

      expect(find.byType(TickerDrivenWidget), findsNothing);

      // Advancing clock when unmounted must not cause errors or orphan tickers
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
