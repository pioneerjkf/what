// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../../models/cart_item.dart';
import '../../models/section.dart';
import '../../sections/scoped_state_di_section.dart';

/// Sub-store for Section 04: Scoped State DI
class ScopedStateDiStore {
  final _item1 = WhatController<CartItem>(
    const CartItem(name: 'Wireless Headphones', price: 120, quantity: 1),
  );

  final _item2 = WhatController<CartItem>(
    const CartItem(name: 'Mechanical Keyboard', price: 85, quantity: 2),
  );

  What<CartItem> get item1 => _item1.what;
  What<CartItem> get item2 => _item2.what;

  /// Automatically computed VIP status when total >= 300 (pure derived state).
  late final isVipUnlocked = computed<bool>((via) {
    final i1 = via(item1);
    final i2 = via(item2);
    return (i1.price * i1.quantity + i2.price * i2.quantity) >= 300;
  });

  void incrementItem1() {
    _item1.set(_item1.data.copyWith(quantity: _item1.data.quantity + 1));
  }

  void decrementItem1() {
    if (_item1.data.quantity > 0) {
      _item1.set(_item1.data.copyWith(quantity: _item1.data.quantity - 1));
    }
  }

  void incrementItem2() {
    _item2.set(_item2.data.copyWith(quantity: _item2.data.quantity + 1));
  }

  void decrementItem2() {
    if (_item2.data.quantity > 0) {
      _item2.set(_item2.data.copyWith(quantity: _item2.data.quantity - 1));
    }
  }

  ShowcaseSection get section => ShowcaseSection(
        id: '04_scoped_state_di',
        number: '04',
        title: 'Scoped State DI (what.provide & whatOf)',
        subtitle: 'Inherited state tree with forced-rebuild suppression',
        badge: 'DI & Scoping',
        icon: Icons.account_tree_rounded,
        codeSnippet: '''
// 1. Parent: Provide state to subtree using what.provide()
final authWhat = WhatController(AuthState(isLoggedIn: true));

Widget buildApp() {
  return authWhat.provide(
    child: const UserDashboard(),
  );
}

// 2. Child: Look up ancestor state reactively without prop drilling
base class UserDashboard extends WhatWidget {
  UserDashboard({super.key});

  // Automatically subscribes to ancestor WhatProvider<AuthState>
  late final authStateWhat = whatOf<AuthState>();

  @override
  Widget build(BuildContext context, WhatVia via) {
    final auth = via(authStateWhat);
    return Text(auth.isLoggedIn ? 'Welcome Back!' : 'Please Sign In');
  }
}''',
        highlights: const [
          'Forced-Rebuild Suppression: WhatProvider suppresses unneeded ancestor/sibling rebuilds.',
          'O(1) Engine Lookups: Leverages Flutter engine internal inherited elements hash table.',
          '2-Axis Cascade Stream: Automatically tracks both tree routing and state mutations.',
        ],
        roadmapTree: '''
[Scoped State DI Hierarchy]
 ├── what.provide(child: ...) / What.constant(store).provide(...) -> Mounts WhatProvider<T>
 └── whatOf<T>()                                            -> O(1) ancestor lookup & reactive binding
''',
        builder: () => ScopedStateDiSectionDemo(),
      );
}
