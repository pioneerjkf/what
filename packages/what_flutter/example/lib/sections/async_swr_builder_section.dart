// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:what_flutter/what_flutter.dart';
import '../components/showcase_card.dart';
import '../store/showcase_store.dart';

/// Section 06: Async UI, SWR & WhatPendingIndicator Showcase Demo.
base class AsyncSwrBuilderSectionDemo extends WhatWidget {
  const AsyncSwrBuilderSectionDemo({super.key});

  @override
  Widget build(BuildContext context, WhatVia via) {
    final store = via.of<ShowcaseStore>(context).sections.asyncSwrBuilder;
    final currentQuery = via(store.query);
    final isPreserve = via(store.preserveData);
    final latency = via(store.latencyMs);
    final fetchCount = via(store.fetchCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------------------
        // Controls & Configuration Card
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: 'Interactive Async Query Control',
          badge: 'SWR Simulation',
          description:
              'Switch queries or simulate slow network responses. When SWR is enabled, prior data remains rendered without flicker while background revalidation occurs.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Query Selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Select Query:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  for (final q in ['Alice', 'Bob', 'Charlie', 'Empty', 'Error'])
                    ChoiceChip(
                      label: Text(q),
                      selected: currentQuery == q,
                      onSelected: (selected) {
                        if (selected) store.setQuery(q);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // SWR & Latency settings
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Preserve Data on Pending (SWR)',
                          style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        isPreserve
                            ? 'Flicker-Free: Retains old state during fetch'
                            : 'Strict: Shows loading spinner on every query',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      value: isPreserve,
                      onChanged: (_) => store.togglePreserveData(),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Latency: ${latency}ms',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(
                        width: 180,
                        child: Slider(
                          value: latency.toDouble(),
                          min: 200,
                          max: 2000,
                          divisions: 9,
                          label: '${latency}ms',
                          onChanged: (val) => store.setLatency(val.round()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Status Summary Bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Total Dispatches: $fetchCount',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Status: ', style: TextStyle(fontSize: 13)),
                        composed((context, via) {
                          final isPending = via(store.pending);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.amber.withAlpha(30)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPending
                                    ? Colors.amber.withAlpha(120)
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(120),
                              ),
                            ),
                            child: Text(
                              isPending ? 'FETCHING' : 'SETTLED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPending
                                    ? Colors.amber
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // Showcase Card 1: WhatAsyncBuilder + WhatPendingIndicator
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: '1. WhatAsyncBuilder & WhatPendingIndicator',
          badge: 'SWR Widget',
          description:
              'WhatPendingIndicator reactively tracks store.pending without rebuilding the rest of the view. WhatAsyncBuilder displays cached data while new data arrives.',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Slim Linear Pending Indicator
                WhatPendingIndicator(
                  target: store.pending,
                  height: 3.5,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withAlpha(30),
                ),

                // Async Builder Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: WhatAsyncBuilder<DemoUser?>(
                    what: store.userProfile,
                    pending: store.pending,
                    preserveDataOnPending: isPreserve,
                    loading: (context) => const _LoadingPlaceholder(),
                    error: (context, error, stack) => _ErrorView(
                      error: error,
                      onRetry: () => store.refresh(),
                    ),
                    empty: (context) => const _EmptyView(),
                    data: (context, user) {
                      if (user == null) return const _EmptyView();
                      return _UserProfileCard(user: user);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // Showcase Card 2: what.build.async Zero-Alloc Functor Cascade
        // ---------------------------------------------------------------------
        ShowcaseCard(
          title: '2. Zero-Allocation Inline Functor (what.build.async)',
          badge: 'Functor Extension',
          description:
              'Provides zero-runtime allocation inline declarative asynchronous UI composition directly on any What node.',
          child: store.userProfile.build.async(
            pending: store.pending,
            preserveDataOnPending: isPreserve,
            loading: (context) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (context, err, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Inline Error: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            empty: (context) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No profile loaded (Empty result)'),
              ),
            ),
            data: (context, user) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user != null && user.name.isNotEmpty ? user.name[0] : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(user?.name ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(user?.bio ?? ''),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({required this.user});

  final DemoUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.id,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.role,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.bio,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fetched at: ${user.fetchedAt.toIso8601String().substring(11, 19)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Fetching remote profile in progress...',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fetch Error Encountered',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(fontSize: 13, color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry Query'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No user profile found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
