import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:approvals_hte/features/scan/presentation/providers/scan_providers.dart';

class MenuGrid extends ConsumerWidget {
  const MenuGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastQr = ref.watch(lastScannedQrProvider);
    final lastWo = lastQr == null ? null : _extractWoCode(lastQr);

    final items = <_MenuItem>[
      _MenuItem(
        icon: Icons.folder_special_rounded,
        title: 'Dokumen Work Order',
        subtitle: lastWo == null
            ? 'Buka daftar dokumen'
            : 'Terakhir: $lastWo',
        onTap: () {
          final encoded = lastQr == null ? '' : Uri.encodeComponent(lastQr);
          context.push(
            lastQr == null ? '/documents' : '/documents?qr=$encoded',
          );
        },
      ),
      _MenuItem(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Scan Dokumen',
        subtitle: 'Buka pemindai QR',
        onTap: () => context.push('/scan'),
      ),
      _MenuItem(
        icon: Icons.done_all_rounded,
        title: 'Auto Approve',
        subtitle: 'Approve semua dokumen pending',
        onTap: () => context.push('/auto-approve'),
      ),
      _MenuItem(
        icon: Icons.block_rounded,
        title: 'Auto Reject + Reason',
        subtitle: 'Tolak massal dengan alasan sama',
        onTap: () => context.push('/auto-reject'),
      ),
      _MenuItem(
        icon: Icons.check_circle_outline,
        title: 'Auto Approve (Single)',
        subtitle: 'Approve satu dokumen via QR',
        onTap: () => context.push('/auto-approve-single'),
      ),
      _MenuItem(
        icon: Icons.close_rounded,
        title: 'Auto Reject (Single)',
        subtitle: 'Reject dokumen tunggal + alasan',
        onTap: () => context.push('/auto-reject-single'),
      ),
    ];

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
        final itemWidth = safeColumns == 0
            ? maxWidth
            : availableWidth / safeColumns;
        final children = <Widget>[
          for (final item in items)
            SizedBox(
              width: itemWidth,
              child: _MenuCard(item: item),
            ),
          SizedBox(width: maxWidth, height: _bottomSpacerHeight),
        ];

        final grid = Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children,
        );

        final ancestorScrollable = Scrollable.maybeOf(context);
        if (ancestorScrollable != null) {
          return grid;
        }
        return LayoutBuilder(
          builder: (context, innerConstraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: innerConstraints.maxHeight,
                  minWidth: double.infinity,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: grid,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MenuItem {
  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item});
  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 36),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _extractWoCode(String qrText) {
  final parts = qrText.split(';');
  for (final part in parts) {
    if (part.startsWith('WO=')) {
      final value = part.substring(3);
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

const double _bottomSpacerHeight = 100;
