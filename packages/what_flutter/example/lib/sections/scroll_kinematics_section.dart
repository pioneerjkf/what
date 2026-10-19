// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';

class ScrollKinematicsSection extends StatefulWidget {
  const ScrollKinematicsSection({super.key});

  @override
  State<ScrollKinematicsSection> createState() =>
      _ScrollKinematicsSectionState();
}

class _ScrollKinematicsSectionState extends State<ScrollKinematicsSection> {
  late final ScrollController scrollController;
  late final What<double> scrollOffset;
  late final What<double> appBarOpacity;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();

    // 1. Bridge the ScrollController offset into the reactive graph
    scrollOffset = scrollController.toWhatBy(
      (ctrl) => ctrl.hasClients ? ctrl.offset : 0.0,
    );

    // 2. Compute a normalized opacity (0.0 to 1.0) based on scroll depth
    appBarOpacity = computed((via) {
      final offset = via(scrollOffset);
      return (offset / 150.0).clamp(0.0, 1.0);
    }).distinct(); // distinct() halts downstream propagation when saturated
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400, // Fixed height for showcase purposes
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // The heavy list that NEVER rebuilds during scroll
          ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(
                top: 100, bottom: 200), // padding for the app bar
            itemCount: 100,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Text(
                        'Zero-Allocation 120fps Rebuilds\n\n'
                        'Scroll down this list. The custom AppBar above will fade in based on the scroll offset.\n\n'
                        'Notice that this massive ListView NEVER rebuilds. Only the tiny Opacity widget wrapping the AppBar is rebuilt.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(150),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SCROLL DOWN',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              }
              return ListTile(
                leading: CircleAvatar(child: Text('$index')),
                title: Text('Heavy Feed Item $index'),
                subtitle: const Text('Simulating a heavy widget tree...'),
              );
            },
          ),

          // The surgical micro-rebuild zone
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: composed((context, via) {
              final opacity = via(appBarOpacity);

              // Rebuilds at 120fps but ONLY this widget
              return Opacity(
                opacity: opacity,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: const Text(
                    'Dynamic Surgical AppBar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
