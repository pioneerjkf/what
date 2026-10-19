// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/what_flutter.dart';

void main() {
  group('WhatTextEditingController Comprehensive Test Suite', () {
    group('1. Bidirectional State Synchronization', () {
      test('Initial value synchronization from target WhatController', () {
        final target = WhatController<String>('initial text');
        final controller = WhatTextEditingController(target);

        expect(controller.text, 'initial text');
        expect(target.data, 'initial text');
        expect(controller.target, equals(target));
        expect(controller.toString(), contains('initial text'));

        controller.dispose();
      });

      test('Explicit text parameter initializes target when different', () {
        final target = WhatController<String>('target text');
        final controller =
            WhatTextEditingController(target, text: 'explicit text');

        expect(controller.text, 'explicit text');
        expect(target.data, 'explicit text');

        controller.dispose();
      });

      test('UI-initiated mutation synchronizes immediately to WhatController',
          () {
        final target = WhatController<String>('hello');
        final controller = WhatTextEditingController(target);

        expect(controller.text, 'hello');

        controller.text = 'world';
        expect(target.data, 'world');

        controller.dispose();
      });

      test(
          'State-initiated mutation synchronizes immediately to TextEditingController',
          () {
        final target = WhatController<String>('hello');
        final controller = WhatTextEditingController(target);

        target.set('from reactive state');
        expect(controller.text, 'from reactive state');

        controller.dispose();
      });

      test(
          'Identical value mutation short-circuits without extra notifications',
          () {
        final target = WhatController<String>('stable');
        final controller = WhatTextEditingController(target);

        int controllerNotifyCount = 0;
        controller.addListener(() => controllerNotifyCount++);

        target.set('stable');
        expect(controllerNotifyCount, 0);

        controller.dispose();
      });

      test('Target empty resets text when clearOnEmpty is true', () {
        final target = WhatController<String>('filled');
        final controller =
            WhatTextEditingController(target, clearOnEmpty: true);

        expect(controller.text, 'filled');

        target.empty();
        expect(controller.text, '');

        controller.dispose();
      });

      test('Target empty preserves text when clearOnEmpty is false', () {
        final target = WhatController<String>('filled');
        final controller =
            WhatTextEditingController(target, clearOnEmpty: false);

        expect(controller.text, 'filled');

        target.empty();
        expect(controller.text, 'filled');

        controller.dispose();
      });

      test(
          'Extension bindTextController creates properly synchronized controller',
          () {
        final target = WhatController<String>('via extension');
        final controller = target.bindTextController();

        expect(controller.text, 'via extension');
        controller.text = 'updated via controller';
        expect(target.data, 'updated via controller');

        target.set('updated via state');
        expect(controller.text, 'updated via state');

        controller.dispose();
      });
    });

    group('2. Zero-Jump Cursor & IME Selection Protection', () {
      test(
          'Preserves existing cursor position within bounds on external mutation',
          () {
        final target = WhatController<String>('hello world');
        final controller = WhatTextEditingController(target);

        // Place cursor right after 'hello' (offset 5)
        controller.selection = const TextSelection.collapsed(offset: 5);

        // State changes to a longer text
        target.set('hello reactive universe');

        expect(controller.text, 'hello reactive universe');
        // Cursor stays at offset 5 instead of jumping to end!
        expect(controller.selection.baseOffset, 5);
        expect(controller.selection.extentOffset, 5);

        controller.dispose();
      });

      test('Safely clamps cursor position when external text shrinks', () {
        final target = WhatController<String>('hello world');
        final controller = WhatTextEditingController(target);

        // Place cursor at end of 'hello world' (offset 11)
        controller.selection = const TextSelection.collapsed(offset: 11);

        // State shrinks to 'hi' (length 2)
        target.set('hi');

        expect(controller.text, 'hi');
        // Safely clamped to 2, no RangeError or crash!
        expect(controller.selection.baseOffset, 2);
        expect(controller.selection.extentOffset, 2);

        controller.dispose();
      });

      test('Preserves range selection (highlight) clamped safely', () {
        final target = WhatController<String>('0123456789');
        final controller = WhatTextEditingController(target);

        // Highlight '234'
        controller.selection =
            const TextSelection(baseOffset: 2, extentOffset: 5);

        // State mutates
        target.set('0123456789ABCDEF');

        expect(controller.selection.baseOffset, 2);
        expect(controller.selection.extentOffset, 5);

        controller.dispose();
      });

      test('Invalid selection safely defaults to collapsed at end of text', () {
        final target = WhatController<String>('abc');
        final controller = WhatTextEditingController(target);

        controller.selection = const TextSelection.collapsed(offset: -1);

        target.set('abcdef');
        expect(controller.selection.baseOffset, 6);
        expect(controller.selection.extentOffset, 6);

        controller.dispose();
      });

      test(
          'Composing range is preserved during typing and cleared on external replace',
          () {
        final target = WhatController<String>('');
        final controller = WhatTextEditingController(target);

        // Simulating IME typing
        controller.value = const TextEditingValue(
          text: '한',
          composing: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 1),
        );

        expect(target.data, '한');
        expect(controller.value.composing, const TextRange(start: 0, end: 1));

        // External state replacement clears composing
        target.set('완전');
        expect(controller.value.composing, TextRange.empty);

        controller.dispose();
      });
    });

    group('3. Re-entrancy Ping-Pong Loop Guard', () {
      test('UI update triggers exactly one state update without ping-pong echo',
          () async {
        final target = WhatController<String>('a');
        final controller = WhatTextEditingController(target);

        int targetUpdates = 0;
        int controllerNotifies = 0;

        final runner = target.what.effect(() => targetUpdates++).run();
        controller.addListener(() => controllerNotifies++);

        controller.text = 'b';
        await pumpEventQueue();

        expect(target.data, 'b');
        expect(targetUpdates, 1);
        expect(controllerNotifies, 1);

        runner.deactivate();
        controller.dispose();
      });

      test(
          'State update triggers exactly one controller notification without ping-pong echo',
          () async {
        final target = WhatController<String>('a');
        final controller = WhatTextEditingController(target);

        int targetUpdates = 0;
        int controllerNotifies = 0;

        final runner = target.what.effect(() => targetUpdates++).run();
        controller.addListener(() => controllerNotifies++);

        target.set('c');
        await pumpEventQueue();

        expect(controller.text, 'c');
        expect(targetUpdates, 1);
        expect(controllerNotifies, 1);

        runner.deactivate();
        controller.dispose();
      });
    });

    group('4. Lifecycle & Auto-Disposal', () {
      test('Manual dispose deactivates terminal and detaches listeners', () {
        final target = WhatController<String>('active');
        final controller = WhatTextEditingController(target);

        expect(controller.isDisposed, isFalse);

        controller.dispose();
        expect(controller.isDisposed, isTrue);

        // Multiple disposes are safe
        controller.dispose();

        // Target changes after dispose do not affect controller
        target.set('ignored');
        expect(controller.text, 'active');
      });

      testWidgets(
          'managed<WhatTextEditingController> auto-disposes upon widget unmount via Inactive Dormancy',
          (tester) async {
        final query = WhatController<String>('query');
        final managedCtrlWhat = managed<WhatTextEditingController>(
          create: (_) => WhatTextEditingController(query),
          dispose: (c) => c.dispose(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: _TestSearchWidget(controllerWhat: managedCtrlWhat),
          ),
        );

        final capturedController = managedCtrlWhat.peek;
        expect(capturedController.isDisposed, isFalse);
        expect(capturedController.text, 'query');

        // Unmount widget by pumping a replacement (0 subscribers remaining)
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Inactive dormancy triggers dispose
        expect(capturedController.isDisposed, isTrue);
      });

      testWidgets(
          'controller instance is strictly preserved and NOT re-initialized across widget rebuilds',
          (tester) async {
        final query = WhatController<String>('hello');
        final counter = WhatController<int>(0);
        final managedCtrlWhat = managed<WhatTextEditingController>(
          create: (_) => WhatTextEditingController(query),
          dispose: (c) => c.dispose(),
        );
        final controllersSeen = <WhatTextEditingController>[];

        await tester.pumpWidget(
          MaterialApp(
            home: composed((context, via) {
              final ctrl = via(managedCtrlWhat);
              final count = via(counter.what);
              controllersSeen.add(ctrl);
              return Text('Count: $count');
            }),
          ),
        );

        expect(controllersSeen.length, 1);
        final first = controllersSeen.first;

        // Trigger multiple widget rebuilds via unrelated counter mutation
        counter.set(1);
        await tester.pump();
        counter.set(2);
        await tester.pump();

        expect(controllersSeen.length, 3);
        expect(identical(controllersSeen[0], controllersSeen[1]), isTrue);
        expect(identical(controllersSeen[1], controllersSeen[2]), isTrue);
        expect(first.isDisposed, isFalse);

        // Unmount
        await tester.pumpWidget(const SizedBox());
        expect(first.isDisposed, isTrue);
      });
    });

    group('5. Flutter Widget Integration (TextField)', () {
      testWidgets('Typing into TextField updates WhatController',
          (tester) async {
        final query = WhatController<String>('');
        final controller = WhatTextEditingController(query);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(controller: controller),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'typing test');
        expect(query.data, 'typing test');

        controller.dispose();
      });

      testWidgets('Mutating WhatController updates TextField display smoothly',
          (tester) async {
        final query = WhatController<String>('initial');
        final controller = WhatTextEditingController(query);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(controller: controller),
            ),
          ),
        );

        expect(find.text('initial'), findsOneWidget);

        query.set('updated from backend');
        await tester.pump();

        expect(find.text('updated from backend'), findsOneWidget);

        controller.dispose();
      });
    });
  });
}

final class _TestSearchWidget extends WhatWidget {
  _TestSearchWidget({
    required this.controllerWhat,
  });

  final What<WhatTextEditingController> controllerWhat;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final controller = via(controllerWhat);
    return Scaffold(
      body: TextField(controller: controller),
    );
  }
}
