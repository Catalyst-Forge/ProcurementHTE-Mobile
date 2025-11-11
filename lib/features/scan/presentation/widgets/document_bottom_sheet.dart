import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net;
import 'package:approvals_hte/core/widgets/app_loading.dart';
import 'package:approvals_hte/core/widgets/app_snackbar.dart';
import 'package:approvals_hte/features/scan/data/wo_document_repository.dart';
import 'package:approvals_hte/features/scan/domain/models/approval_update_result.dart';
import 'package:approvals_hte/features/scan/domain/models/wo_document.dart';
import 'package:approvals_hte/features/scan/presentation/pages/document_viewer_page.dart';
import 'package:approvals_hte/features/scan/presentation/providers/scan_providers.dart';

String formatDocumentDate(DateTime? dt) {
  if (dt == null) return '-';
  final local = dt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class DocumentBottomSheet extends ConsumerStatefulWidget {
  const DocumentBottomSheet({super.key, required this.qrText});

  final String qrText;

  @override
  ConsumerState<DocumentBottomSheet> createState() =>
      _DocumentBottomSheetState();
}

class _DocumentBottomSheetState
    extends ConsumerState<DocumentBottomSheet> {
  late Future<WoDocument> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      ref.read(lastScannedQrProvider.notifier).setQr(widget.qrText);
    });
    _future = ref.read(woDocumentRepositoryProvider).fetchByQr(
          widget.qrText,
        );
  }

  void _retry() {
    setState(() {
      _future = ref.read(woDocumentRepositoryProvider).fetchByQr(
            widget.qrText,
          );
    });
  }

  Future<void> _openDocument(WoDocument doc) async {
    final uri = Uri.tryParse(doc.viewUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL dokumen tidak valid.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerPage(
          url: uri.toString(),
          fileName: doc.fileName,
        ),
      ),
    );
  }

  Future<void> _handleApprovalAction(
    WoDocument doc,
    ApprovalAction action,
  ) async {
    if (_submitting) return;

    final repo = ref.read(woDocumentRepositoryProvider);
    String? note;

    if (action == ApprovalAction.reject) {
      note = await showRejectNoteDialog(context);
      if (!mounted || note == null) return;
    } else {
      final confirmed = await showApprovalConfirmDialog(
        context,
        action: action,
        fileName: doc.fileName,
      );
      if (!mounted || !confirmed) return;
    }

    setState(() => _submitting = true);
    try {
      final result =
          await repo.updateApprovalStatusByDocumentId(
        woDocumentId: doc.woDocumentId,
        action: action,
        note: note,
      );
      if (!mounted) return;
      await showApprovalResultDialog(context, result);
      if (result.ok) {
        _retry();
      }
    } on net.AppFailure catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FutureBuilder<WoDocument>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return SizedBox(
                    height: 220,
                    child: Center(
                      child:
                          CircularProgressIndicator(color: cs.primary),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  final err = snapshot.error;
                  String message = 'Terjadi kesalahan.';
                  if (err is net.AppFailure &&
                      err.message.isNotEmpty) {
                    message = err.message;
                  } else if (err != null &&
                      err.toString().isNotEmpty) {
                    message = err.toString();
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_rounded, color: cs.error),
                          const SizedBox(width: 8),
                          const Text(
                            'Gagal memuat dokumen',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba Lagi'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                    ],
                  );
                }

            final doc = snapshot.data!;
            final isUploadedStatus =
                doc.status.trim().toLowerCase() == 'uploaded';
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.description_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dokumen Work Order',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc.fileName,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StatusBadge(status: doc.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoTile(
                    label: 'Dibuat Oleh',
                    value: doc.createdByUserName,
                  ),
                  InfoTile(
                    label: 'Dibuat Pada',
                    value: formatDocumentDate(doc.createdAt),
                  ),
                  if (doc.description != null && doc.description!.isNotEmpty)
                    InfoTile(label: 'Deskripsi', value: doc.description!),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openDocument(doc),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Buka Dokumen'),
                      ),
                      if (!isUploadedStatus) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                          ),
                          onPressed: () => _handleApprovalAction(
                            doc,
                            ApprovalAction.reject,
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.tertiaryContainer,
                            foregroundColor: cs.onTertiaryContainer,
                          ),
                          onPressed: () => _handleApprovalAction(
                            doc,
                            ApprovalAction.approve,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Approve'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
          ),
          if (_submitting)
            const Positioned.fill(
              child: AppLoading(visible: true),
            ),
        ],
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lower = status.toLowerCase();

    Color bg;
    Color fg;
    if (lower.contains('approve')) {
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
    } else if (lower.contains('reject') || lower.contains('decline')) {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
    } else if (lower.contains('pending') || lower.contains('waiting')) {
      bg = cs.tertiaryContainer;
      fg = cs.onTertiaryContainer;
    } else {
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

Future<bool> showApprovalConfirmDialog(
  BuildContext context, {
  required ApprovalAction action,
  String? fileName,
}) async {
  final label = action == ApprovalAction.approve ? 'Approve' : 'Reject';
  final target =
      (fileName == null || fileName.isEmpty) ? 'dokumen ini' : fileName;
  final message = action == ApprovalAction.approve
      ? 'Anda yakin ingin approve $target?'
      : 'Anda yakin ingin reject $target?';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$label Dokumen'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(label),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showRejectNoteDialog(BuildContext context) async {
  final result = await showDialog<String?>(
    context: context,
    builder: (context) => const _RejectNoteDialog(),
  );
  if (result == null) return null;
  final trimmed = result.trim();
  return trimmed;
}

Future<void> showApprovalResultDialog(
  BuildContext context,
  ApprovalUpdateResult result,
) async {
  final title = result.ok ? 'Berhasil' : 'Gagal';
  final details = result.buildDetails();
  final message = result.buildHeadline();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...details.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      );
    },
  );
}

class _RejectNoteDialog extends StatefulWidget {
  const _RejectNoteDialog();

  @override
  State<_RejectNoteDialog> createState() => _RejectNoteDialogState();
}

class _RejectNoteDialogState extends State<_RejectNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alasan Reject'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Catatan (opsional)',
          hintText: 'Tuliskan alasan penolakan',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _controller.text,
          ),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}
