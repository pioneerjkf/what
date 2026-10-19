// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../models/cart_item.dart';
import '../store/showcase_store.dart';

/// Section 04: Scoped State Provision & Dependency Injection (`what.provide` & `whatOf<T>()`)
base class ScopedStateDiSectionDemo extends WhatWidget {
  const ScopedStateDiSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.scopedStateDi;
    // [Lifecycle] Declarative Scoped Effect: Automatically anchored to this widget's lifecycle via tether!
    // Triggers an external one-shot UI side-effect (Milestone SnackBar) strictly upon milestone mutation.
    via.tether(store.isVipUnlocked.effect(() {
      if (store.isVipUnlocked.peek) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('VIP Milestone Unlocked! Cart Total >= \$300'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }));

    return Column(
      children: [
        ShowcaseCard(
          title: 'Scoped State DI & 2-Axis Cascade Stream',
          badge: 'what.provide() & cascade()',
          description:
              'what.provide() distributes state down the tree without prop-drilling. whatOf<T>() accesses ancestor state in O(1), and .cascade() fuses tree changes into a reactive stream.',
          child: Column(
            children: [
              SandboxContainer(
                child: Column(
                  children: [
                    // Item 1 Scope
                    store.item1.provide(
                      child: ItemCard(
                        onAdd: store.incrementItem1,
                        onRemove: store.decrementItem1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Item 2 Scope
                    store.item2.provide(
                      child: ItemCard(
                        onAdd: store.incrementItem2,
                        onRemove: store.decrementItem2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Reactive Effect Threshold Banner
                    composed((context, via) {
                      final isVip = via(store.isVipUnlocked);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isVip
                              ? Colors.amber.withAlpha(35)
                              : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isVip
                                ? Colors.amber
                                : Colors.grey.withAlpha(60),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            isVip
                                ? 'VIP (\$300+): Free Shipping via (item1, item2).effect!'
                                : 'Cart < \$300 (Add items to trigger Effect)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVip
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.amberAccent
                                      : Colors.amber.shade900)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Child widget consuming ancestor CartItem state via `whatOf<CartItem>()`
base class ItemCard extends WhatWidget {
  const ItemCard({
    super.key,
    required this.onAdd,
    required this.onRemove,
  });

  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WhatVia via) {
    // Reactively discovers & observes ancestor WhatProvider<CartItem>
    final item = via.of<CartItem>(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${item.price} each (Total: \$${item.price * item.quantity})',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: item.quantity > 0 ? onRemove : null,
                icon: const Text('-',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                visualDensity: VisualDensity.compact,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: onAdd,
                icon: const Text('+',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
