// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what_flutter/framework.dart';

// 1. Basic Multi-source WhatWidget
base class UserProfileWhatWidget extends WhatWidget {
  const UserProfileWhatWidget({
    super.key,
    required this.nameWhat,
    required this.ageWhat,
  });

  final What<String> nameWhat;
  final What<int> ageWhat;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final name = via(nameWhat);
    final age = via(ageWhat);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('$name: $age'),
    );
  }
}

// 2. Dynamic Branch Switching WhatWidget
base class DynamicBranchWhatWidget extends WhatWidget {
  const DynamicBranchWhatWidget({
    super.key,
    required this.usePrimaryWhat,
    required this.primaryWhat,
    required this.secondaryWhat,
  });

  final What<bool> usePrimaryWhat;
  final What<String> primaryWhat;
  final What<String> secondaryWhat;

  @override
  Widget build(BuildContext context, WhatVia via) {
    final usePrimary = via(usePrimaryWhat);
    final content = usePrimary ? via(primaryWhat) : via(secondaryWhat);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(content),
    );
  }
}

void main() {
  group('WhatWidget & WhatElement Comprehensive Tests', () {
    testWidgets('Renders and dynamically updates when accessed whats change',
        (tester) async {
      final nameController = WhatController<String>('Alice');
      final ageController = WhatController<int>(25);

      await tester.pumpWidget(
        UserProfileWhatWidget(
          nameWhat: nameController.what,
          ageWhat: ageController.what,
        ),
      );

      expect(find.text('Alice: 25'), findsOneWidget);

      // Mutate name
      nameController.set('Bob');
      await tester.pump();
      expect(find.text('Bob: 25'), findsOneWidget);

      // Mutate age
      ageController.set(30);
      await tester.pump();
      expect(find.text('Bob: 30'), findsOneWidget);
    });

    testWidgets(
        'Dynamically switches branches and prunes unobserved dependencies',
        (tester) async {
      final usePrimaryController = WhatController<bool>(true);
      final primaryController = WhatController<String>('Primary Content');
      final secondaryController = WhatController<String>('Secondary Content');

      await tester.pumpWidget(
        DynamicBranchWhatWidget(
          usePrimaryWhat: usePrimaryController.what,
          primaryWhat: primaryController.what,
          secondaryWhat: secondaryController.what,
        ),
      );

      // Initial: primary is watched
      expect(find.text('Primary Content'), findsOneWidget);

      // Mutating secondary should NOT trigger rebuild while branch is primary
      secondaryController.set('Updated Secondary');
      await tester.pump();
      expect(find.text('Primary Content'), findsOneWidget);

      // Switch branch to false -> watches secondary, prunes primary
      usePrimaryController.set(false);
      await tester.pump();
      expect(find.text('Updated Secondary'), findsOneWidget);

      // Mutating primary should now NOT trigger rebuild because primary was pruned!
      primaryController.set('Ignored Primary Update');
      await tester.pump();
      expect(find.text('Updated Secondary'), findsOneWidget);

      // Mutating secondary triggers rebuild
      secondaryController.set('Active Secondary');
      await tester.pump();
      expect(find.text('Active Secondary'), findsOneWidget);
    });

    testWidgets(
        'WhatWidget dynamically updates compute when widget configuration changes',
        (tester) async {
      final whatA = WhatController<int>(10);
      final whatB = WhatController<int>(20);

      await tester.pumpWidget(
        UserProfileWhatWidget(
          nameWhat: WhatController<String>('User').what,
          ageWhat: whatA.what,
        ),
      );
      expect(find.text('User: 10'), findsOneWidget);

      // Update widget with new ageWhat (whatB)
      await tester.pumpWidget(
        UserProfileWhatWidget(
          nameWhat: WhatController<String>('User').what,
          ageWhat: whatB.what,
        ),
      );
      expect(find.text('User: 20'), findsOneWidget);

      // Mutate whatB -> updates
      whatB.set(99);
      await tester.pump();
      expect(find.text('User: 99'), findsOneWidget);
    });
  });
}
