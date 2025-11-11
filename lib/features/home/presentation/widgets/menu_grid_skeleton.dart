import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:approvals_hte/shared/widgets/shimmer.dart';

class MenuGridSkeleton extends StatelessWidget {
  const MenuGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isInfinite
            ? MediaQuery.sizeOf(context).width
            : constraints.maxWidth;
        final columns = maxWidth >= 900
            ? 4
            : maxWidth >= 600
                ? 3
                : 2;
        final spacing = 12.0;
        final safeColumns = math.max(1, columns);
        final totalSpacing = spacing * (safeColumns - 1);
        final availableWidth = math.max(0, maxWidth - totalSpacing);
        final itemWidth =
            safeColumns == 0 ? maxWidth : availableWidth / safeColumns;

        final placeholders = [
          for (var i = 0; i < 6; i++)
            SizedBox(
              width: itemWidth,
              child: const _MenuCardSkeleton(),
            ),
          SizedBox(width: maxWidth, height: _bottomSpacerHeight),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: placeholders,
        );
      },
    );
  }
}

class _MenuCardSkeleton extends StatelessWidget {
  const _MenuCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: const BoxConstraints(minHeight: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 140,
              height: 10,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double _bottomSpacerHeight = 100;
