import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net;
import 'package:approvals_hte/core/widgets/app_snackbar.dart';
import 'package:approvals_hte/features/scan/data/wo_document_repository.dart';
import 'package:approvals_hte/features/scan/domain/models/approval_update_result.dart';
import 'package:approvals_hte/features/scan/domain/models/wo_document.dart';
import 'package:approvals_hte/features/scan/presentation/pages/document_scan_page.dart';
import 'package:approvals_hte/features/scan/presentation/providers/scan_providers.dart';

class AutoApprovePage extends AutoActionPage {
  const AutoApprovePage({super.key})
    : super(
        title: 'Auto Approve',
        description:
            'Setujui seluruh dokumen pending berdasarkan QR / Work Order yang sama.',
        submitLabel: 'Approve Semua',
        action: ApprovalAction.approve,
        icon: Icons.done_all_rounded,
      );
}

class AutoRejectPage extends AutoActionPage {
  const AutoRejectPage({super.key})
    : super(
        title: 'Auto Reject',
        description:
            'Tolak seluruh dokumen pending sekaligus dengan alasan yang sama.',
        submitLabel: 'Reject Semua',
        action: ApprovalAction.reject,
        icon: Icons.close_rounded,
        noteLabel: 'Alasan Penolakan',
        noteHint: 'Contoh: Dokumen tidak sesuai',
        noteRequired: true,
      );
}

class AutoActionPage extends ConsumerStatefulWidget {
  const AutoActionPage({
    super.key,
    required this.title,
    required this.description,
    required this.submitLabel,
    required this.action,
    required this.icon,
    this.noteLabel,
    this.noteHint,
    this.noteRequired = false,
  });

  final String title;
  final String description;
  final String submitLabel;
  final ApprovalAction action;
  final IconData icon;
  final String? noteLabel;
  final String? noteHint;
  final bool noteRequired;

  @override
  ConsumerState<AutoActionPage> createState() => _AutoActionPageState();
}

class _AutoActionPageState extends ConsumerState<AutoActionPage> {
  static const int _fetchPageSize = 50;

  late final TextEditingController _qrController;
  late final TextEditingController _noteController;
  bool _processing = false;
  bool _hasRun = false;
  _AutoActionStats? _stats;
  List<_AutoActionLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    _qrController = TextEditingController(
      text: ref.read(lastScannedQrProvider) ?? '',
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _qrController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DocumentScanPage(),
        fullscreenDialog: true,
      ),
    );
    final scanned = ref.read(lastScannedQrProvider);
    if (scanned != null && scanned.isNotEmpty) {
      setState(() => _qrController.text = scanned);
    }
  }

  void _useLastQr() {
    final last = ref.read(lastScannedQrProvider);
    if (last == null || last.isEmpty) {
      AppSnackBar.show(context, 'Belum ada QR yang tersimpan.');
      return;
    }
    setState(() => _qrController.text = last);
  }

  Future<void> _runAutoAction() async {
    final qrText = _qrController.text.trim();
    final note = _noteController.text.trim();

    if (qrText.isEmpty) {
      AppSnackBar.show(context, 'QR / kode dokumen wajib diisi.');
      return;
    }
    if (widget.noteRequired && note.isEmpty) {
      AppSnackBar.show(context, 'Alasan penolakan wajib diisi.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _processing = true;
      _hasRun = false;
      _logs = const [];
      _stats = null;
    });

    final repo = ref.read(woDocumentRepositoryProvider);

    try {
      final docs = await _fetchAllDocuments(repo, qrText);
      if (!mounted) return;
      if (docs.isEmpty) {
        AppSnackBar.show(context, 'Tidak ada dokumen untuk QR tersebut.');
        setState(() {
          _processing = false;
          _hasRun = true;
          _stats = const _AutoActionStats(
            totalDocs: 0,
            actionableDocs: 0,
            skippedDocs: 0,
            success: 0,
            failed: 0,
          );
        });
        return;
      }

      final actionable = docs.where(_isActionable).toList();
      if (actionable.isEmpty) {
        AppSnackBar.show(context, 'Semua dokumen sudah diproses sebelumnya.');
        setState(() {
          _processing = false;
          _hasRun = true;
          _stats = _AutoActionStats(
            totalDocs: docs.length,
            actionableDocs: 0,
            skippedDocs: docs.length,
            success: 0,
            failed: 0,
          );
        });
        return;
      }

      final logs = <_AutoActionLog>[];
      var success = 0;
      var failed = 0;
      for (final doc in actionable) {
        if (!mounted) return;
        try {
          final result = await repo.updateApprovalStatusByDocumentId(
            woDocumentId: doc.woDocumentId,
            action: widget.action,
            note: widget.action == ApprovalAction.reject ? note : null,
          );
          final ok = result.ok;
          logs.add(
            _AutoActionLog(doc: doc, ok: ok, message: result.buildHeadline()),
          );
          if (ok) {
            success++;
          } else {
            failed++;
          }
        } on net.AppFailure catch (e) {
          logs.add(_AutoActionLog(doc: doc, ok: false, message: e.message));
          failed++;
        } catch (e) {
          logs.add(_AutoActionLog(doc: doc, ok: false, message: e.toString()));
          failed++;
        }
      }

      if (!mounted) return;
      setState(() {
        _processing = false;
        _hasRun = true;
        _logs = logs;
        _stats = _AutoActionStats(
          totalDocs: docs.length,
          actionableDocs: actionable.length,
          skippedDocs: docs.length - actionable.length,
          success: success,
          failed: failed,
        );
      });
    } on net.AppFailure catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.message);
      setState(() {
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.toString());
      setState(() {
        _processing = false;
      });
    }
  }

  Future<List<WoDocument>> _fetchAllDocuments(
    WoDocumentRepository repo,
    String qrText,
  ) async {
    final docs = <WoDocument>[];
    var page = 1;
    while (true) {
      final batch = await repo.fetchListByQr(
        qrText: qrText,
        page: page,
        pageSize: _fetchPageSize,
      );
      docs.addAll(batch.items);
      if (page >= batch.meta.totalPages) break;
      page++;
    }
    return docs;
  }

  bool _isActionable(WoDocument doc) {
    if (doc.woDocumentId.isEmpty) return false;
    final lower = doc.status.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (lower == 'uploaded') return false;
    if (lower.contains('approve')) return false;
    if (lower.contains('reject')) return false;
    if (lower.contains('decline')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lastQr = ref.watch(lastScannedQrProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (lastQr != null && lastQr.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LastQrBanner(value: lastQr),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _qrController,
              decoration: const InputDecoration(
                labelText: 'QR / Kode Dokumen',
                hintText: 'Contoh: QR=WO=...',
              ),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _useLastQr,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Gunakan QR terakhir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _processing ? null : _startScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan QR'),
                  ),
                ),
              ],
            ),
            if (widget.noteLabel != null) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: widget.noteLabel,
                  hintText: widget.noteHint,
                  helperText: widget.noteRequired
                      ? 'Alasan wajib diisi untuk auto reject.'
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _processing ? null : _runAutoAction,
              icon: Icon(widget.icon),
              label: Text(widget.submitLabel),
            ),
            if (_processing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 4),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _StatsSection(hasRun: _hasRun, stats: _stats),
            const SizedBox(height: 12),
            if (_logs.isNotEmpty)
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => _AutoActionLogTile(
                  log: _logs[index],
                  action: widget.action,
                ),
              )
            else if (_hasRun)
              Text(
                'Tidak ada log untuk ditampilkan.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Text(
                'Hasil akan muncul di sini setelah proses dijalankan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _LastQrBanner extends StatelessWidget {
  const _LastQrBanner({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR terakhir',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.hasRun, required this.stats});

  final bool hasRun;
  final _AutoActionStats? stats;

  @override
  Widget build(BuildContext context) {
    if (!hasRun && stats == null) {
      return Text(
        'Belum ada eksekusi.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (stats == null) {
      return const SizedBox.shrink();
    }
    final items = [
      _StatEntry('Total dokumen', stats!.totalDocs),
      _StatEntry('Siap diproses', stats!.actionableDocs),
      _StatEntry('Dilewati', stats!.skippedDocs),
      _StatEntry('Berhasil', stats!.success),
      _StatEntry('Gagal', stats!.failed),
    ];

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value.toString(),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatEntry {
  const _StatEntry(this.label, this.value);
  final String label;
  final int value;
}

class _AutoActionStats {
  const _AutoActionStats({
    required this.totalDocs,
    required this.actionableDocs,
    required this.skippedDocs,
    required this.success,
    required this.failed,
  });

  final int totalDocs;
  final int actionableDocs;
  final int skippedDocs;
  final int success;
  final int failed;
}

class _AutoActionLog {
  const _AutoActionLog({
    required this.doc,
    required this.ok,
    required this.message,
  });

  final WoDocument doc;
  final bool ok;
  final String message;
}

class _AutoActionLogTile extends StatelessWidget {
  const _AutoActionLogTile({required this.log, required this.action});

  final _AutoActionLog log;
  final ApprovalAction action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = log.ok
        ? cs.primaryContainer.withValues(alpha: 0.4)
        : cs.errorContainer.withValues(alpha: 0.4);
    final icon = log.ok ? Icons.check_circle : Icons.error_rounded;
    final iconColor = log.ok ? cs.onPrimaryContainer : cs.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.doc.fileName.isEmpty
                          ? 'Dokumen tanpa nama'
                          : log.doc.fileName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status awal: ${log.doc.status.isEmpty ? '-' : log.doc.status}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(log.message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            'Action: ${action.label}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
