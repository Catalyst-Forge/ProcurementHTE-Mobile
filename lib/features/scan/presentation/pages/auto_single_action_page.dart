import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net;
import 'package:approvals_hte/core/widgets/app_snackbar.dart';
import 'package:approvals_hte/features/scan/data/wo_document_repository.dart';
import 'package:approvals_hte/features/scan/domain/models/approval_update_result.dart';
import 'package:approvals_hte/features/scan/domain/models/wo_document.dart';
import 'package:approvals_hte/features/scan/presentation/providers/scan_providers.dart';
import 'package:approvals_hte/features/scan/presentation/widgets/document_bottom_sheet.dart'
    show showApprovalResultDialog, showRejectNoteDialog;

class AutoApproveSinglePage extends AutoSingleScanPage {
  const AutoApproveSinglePage({super.key})
      : super(
          title: 'Auto Approve (Single)',
          description:
              'Scan dokumen lalu sistem langsung melakukan approve tanpa perlu konfirmasi lanjutan.',
          action: ApprovalAction.approve,
          icon: Icons.check_circle_rounded,
          accentColor: Colors.green,
          requireNote: false,
        );
}

class AutoRejectSinglePage extends AutoSingleScanPage {
  const AutoRejectSinglePage({super.key})
      : super(
          title: 'Auto Reject (Single)',
          description:
              'Scan dokumen lalu isi alasan penolakan sebelum sistem mengirimkan reject.',
          action: ApprovalAction.reject,
          icon: Icons.close_rounded,
          accentColor: Colors.red,
          requireNote: true,
        );
}

class AutoSingleScanPage extends ConsumerStatefulWidget {
  const AutoSingleScanPage({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
    required this.accentColor,
    required this.requireNote,
  });

  final String title;
  final String description;
  final ApprovalAction action;
  final IconData icon;
  final Color accentColor;
  final bool requireNote;

  @override
  ConsumerState<AutoSingleScanPage> createState() =>
      _AutoSingleScanPageState();
}

class _AutoSingleScanPageState extends ConsumerState<AutoSingleScanPage> {
  late final MobileScannerController _controller;
  bool _processing = false;
  String? _lastQr;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      torchEnabled: false,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    setState(() {
      _processing = true;
      _lastQr = raw;
    });
    ref.read(lastScannedQrProvider.notifier).setQr(raw);
    HapticFeedback.mediumImpact();
    await _controller.stop();

    final repo = ref.read(woDocumentRepositoryProvider);
    try {
      final doc = await repo.fetchByQr(raw);
      if (!mounted) return;

      String? note;
      if (widget.requireNote) {
        note = await showRejectNoteDialog(context);
        if (!mounted) return;
        if (note == null) {
          await _resumeScanning();
          return;
        }
      }

      await _submitAction(repo, doc, note: note);
    } on net.AppFailure catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.message);
      await _resumeScanning();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.toString());
      await _resumeScanning();
    }
  }

  Future<void> _submitAction(
    WoDocumentRepository repo,
    WoDocument doc, {
    String? note,
  }) async {
    try {
      final result =
          await repo.updateApprovalStatusByDocumentId(
        woDocumentId: doc.woDocumentId,
        action: widget.action,
        note: widget.action == ApprovalAction.reject ? note : null,
      );
      if (!mounted) return;
      await showApprovalResultDialog(context, result);
      if (!mounted) return;
      Navigator.of(context).maybePop(result.ok ? 'done' : null);
    } on net.AppFailure catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.message);
      await _resumeScanning();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.toString());
      await _resumeScanning();
    }
  }

  Future<void> _resumeScanning() async {
    setState(() => _processing = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 56, color: cs.error),
                      const SizedBox(height: 12),
                      Text(
                        'Kamera tidak tersedia / izin ditolak.\n$error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Container(decoration: _ScannerOverlay(color: cs.onSurface)),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                _InfoBanner(
                  text: widget.description,
                  icon: widget.icon,
                  color: widget.accentColor,
                ),
                const SizedBox(height: 12),
                if (_lastQr != null)
                  Text(
                    'Terakhir: $_lastQr',
                    style: TextStyle(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends Decoration {
  const _ScannerOverlay({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _ScannerOverlayPainter(color);
}

class _ScannerOverlayPainter extends BoxPainter {
  _ScannerOverlayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size ?? Size.zero;
    final rect = offset & size;
    final cutoutSize = Size(rect.width * 0.7, rect.width * 0.7);
    final cutout = Rect.fromCenter(
      center: rect.center,
      width: cutoutSize.width,
      height: cutoutSize.height,
    );

    final overlayPaint = Paint()..color = const Color(0xB3000000);
    canvas.drawRect(rect, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(cutout, clearPaint);

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutout, const Radius.circular(20)),
      borderPaint,
    );

    canvas.restore();
  }
}
