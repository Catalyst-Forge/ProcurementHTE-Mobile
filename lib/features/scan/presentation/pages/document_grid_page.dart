import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net;
import 'package:approvals_hte/core/widgets/app_snackbar.dart';
import 'package:approvals_hte/features/scan/data/wo_document_repository.dart';
import 'package:approvals_hte/features/scan/domain/models/approval_update_result.dart';
import 'package:approvals_hte/features/scan/domain/models/wo_document.dart';
import 'package:approvals_hte/features/scan/domain/models/wo_document_list.dart';
import 'package:approvals_hte/features/scan/presentation/pages/document_viewer_page.dart';
import 'package:approvals_hte/features/scan/presentation/pages/document_scan_page.dart';
import 'package:approvals_hte/features/scan/presentation/providers/scan_providers.dart';
import 'package:approvals_hte/features/scan/presentation/widgets/document_bottom_sheet.dart'
    show
        StatusBadge,
        formatDocumentDate,
        showApprovalConfirmDialog,
        showApprovalResultDialog,
        showRejectNoteDialog;
import 'package:approvals_hte/shared/widgets/shimmer.dart';

const int _documentPageSize = 20;

class DocumentGridPage extends ConsumerStatefulWidget {
  const DocumentGridPage({super.key, this.initialQrText});

  final String? initialQrText;

  @override
  ConsumerState<DocumentGridPage> createState() => _DocumentGridPageState();
}

class _DocumentGridPageState extends ConsumerState<DocumentGridPage> {

  String? _currentQr;
  ProviderSubscription<String?>? _qrListener;

  @override
  void initState() {
    super.initState();
    final preset = widget.initialQrText ?? ref.read(lastScannedQrProvider);
    if (preset != null && preset.isNotEmpty) {
      _currentQr = preset;
    }

    _qrListener = ref.listenManual<String?>(
      lastScannedQrProvider,
      (_, next) {
        if (!mounted) return;
        if (next == null || next.isEmpty) return;
        _setQr(next);
      },
    );
  }

  @override
  void dispose() {
    _qrListener?.close();
    super.dispose();
  }

  void _setQr(String qr) {
    if (qr == _currentQr) return;
    setState(() => _currentQr = qr);
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DocumentScanPage(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _refresh() async {
    final qr = _currentQr;
    if (qr == null || qr.isEmpty) return;
    try {
      final provider = woDocumentsByQrProvider(
        (qrText: qr, page: 1, pageSize: _documentPageSize),
      );
      final future = ref.refresh(provider.future);
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final qr = _currentQr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Work Order'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Scan dokumen',
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: qr == null || qr.isEmpty
          ? _EmptyDocumentView(onScan: _openScanner)
          : _buildDocuments(context, qr),
    );
  }

  Widget _buildDocuments(BuildContext context, String qr) {
    final docsAsync = ref.watch(
      woDocumentsByQrProvider(
        (qrText: qr, page: 1, pageSize: _documentPageSize),
      ),
    );

    return docsAsync.when(
      data: (result) => _DocumentGridBody(
        result: result,
        qrText: qr,
        onRefresh: _refresh,
      ),
      loading: () => const _DocumentGridLoading(),
      error: (error, _) => _DocumentErrorView(
        message: error.toString(),
        onRetry: _refresh,
      ),
    );
  }
}

class _DocumentGridBody extends StatelessWidget {
  const _DocumentGridBody({
    required this.result,
    required this.qrText,
    required this.onRefresh,
  });

  final WoDocumentListResult result;
  final String qrText;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final createdBy =
        result.items.isNotEmpty ? result.items.first.createdByUserName : null;
    final workOrder = _extractWorkOrderId(qrText);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: result.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 160),
                const Icon(Icons.folder_off_rounded, size: 64),
                const SizedBox(height: 18),
                const Text(
                  'Belum ada dokumen untuk QR ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gunakan tombol Scan di pojok kanan atas untuk memuat dokumen terbaru.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 160),
              ],
            )
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Order terakhir',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            workOrder ?? '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (createdBy != null && createdBy.isNotEmpty) ...[
                          Text(
                            'Dibuat oleh $createdBy',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          'Total dokumen: ${result.meta.totalItems}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Halaman ${result.meta.page} dari ${math.max(1, result.meta.totalPages)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final desired = 320.0;
                    final rawCount = (width / desired).floor();
                    final count =
                        math.max(1, math.min(3, rawCount > 0 ? rawCount : 1));
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _DocumentCard(
                            doc: result.items[index],
                          ),
                          childCount: result.items.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 320,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.doc});

  final WoDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isUploadedStatus =
        doc.status.trim().toLowerCase() == 'uploaded';

    Future<void> openDocument() async {
      final uri = Uri.tryParse(doc.viewUrl);
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL dokumen tidak valid.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentViewerPage(
            url: uri.toString(),
            fileName: doc.fileName,
          ),
        ),
      );
    }

    Future<void> submitAction(ApprovalAction action) async {
      final repo = ref.read(woDocumentRepositoryProvider);
      String? note;

      if (action == ApprovalAction.reject) {
        note = await showRejectNoteDialog(context);
        if (!context.mounted || note == null) return;
      } else {
        final confirmed = await showApprovalConfirmDialog(
          context,
          action: action,
          fileName: doc.fileName,
        );
        if (!context.mounted || !confirmed) return;
      }

      final navigator = Navigator.of(context, rootNavigator: true);
      var loadingShown = false;
      void closeLoading() {
        if (!loadingShown) return;
        if (navigator.mounted) {
          navigator.pop();
        }
        loadingShown = false;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      loadingShown = true;

      try {
        final result =
            await repo.updateApprovalStatusByDocumentId(
          woDocumentId: doc.woDocumentId,
          action: action,
          note: note,
        );
        if (!context.mounted) {
          closeLoading();
          return;
        }
        closeLoading();
        await showApprovalResultDialog(context, result);
        if (result.ok && doc.qrText.isNotEmpty) {
          ref.invalidate(
            woDocumentsByQrProvider((
              qrText: doc.qrText,
              page: 1,
              pageSize: _documentPageSize,
            )),
          );
        }
      } on net.AppFailure catch (e) {
        closeLoading();
        if (!context.mounted) return;
        AppSnackBar.show(context, e.message);
      } catch (e) {
        closeLoading();
        if (!context.mounted) return;
        AppSnackBar.show(context, e.toString());
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(status: doc.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dibuat ${formatDocumentDate(doc.createdAt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (doc.description != null && doc.description!.isNotEmpty)
            Text(
              doc.description!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Text(
              '-',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          const Spacer(),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: openDocument,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Buka Dokumen'),
            ),
          ),
          if (!isUploadedStatus) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                      ),
                      onPressed: () => submitAction(ApprovalAction.reject),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.tertiaryContainer,
                        foregroundColor: cs.onTertiaryContainer,
                      ),
                      onPressed: () => submitAction(ApprovalAction.approve),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentErrorView extends StatelessWidget {
  const _DocumentErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Tidak dapat memuat dokumen',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDocumentView extends StatelessWidget {
  const _EmptyDocumentView({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 72, color: cs.primary),
            const SizedBox(height: 20),
            Text(
              'Silakan scan terlebih dahulu',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Gunakan tombol Scan di pojok kanan atas atau tekan tombol di bawah ini untuk memindai QR dokumen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Mulai Scan'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _extractWorkOrderId(String qrText) {
  final parts = qrText.split(';');
  for (final part in parts) {
    if (part.startsWith('WO=')) {
      final value = part.substring(3);
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

class _DocumentGridLoading extends StatelessWidget {
  const _DocumentGridLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        AppShimmer(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 220,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            4,
            (_) => const _DocumentSkeletonCard(),
          ),
        ),
      ],
    );
  }
}

class _DocumentSkeletonCard extends StatelessWidget {
  const _DocumentSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth >= 600 ? 280.0 : screenWidth - 32;
    return SizedBox(
      width: cardWidth,
      child: AppShimmer(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
