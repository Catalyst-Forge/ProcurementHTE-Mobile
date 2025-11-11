import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:approvals_hte/features/scan/presentation/providers/scan_providers.dart';
import 'package:approvals_hte/features/scan/presentation/widgets/document_bottom_sheet.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
    facing: CameraFacing.back,
  );

  bool _handling = false;
  String? _lastRaw;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || capture.barcodes.isEmpty) return;

    final raw = capture.barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    setState(() {
      _handling = true;
      _lastRaw = raw;
    });
    ref.read(lastScannedQrProvider.notifier).setQr(raw);
    HapticFeedback.mediumImpact();
    await _controller.stop();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DocumentBottomSheet(qrText: raw),
    );

    if (!mounted) return;
    setState(() => _handling = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Dokumen / QR'),
        centerTitle: false,
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              final unavailable =
                  state.torchState == TorchState.unavailable;
              return IconButton(
                tooltip: unavailable
                    ? 'Lampu tidak tersedia'
                    : (on ? 'Matikan lampu' : 'Nyalakan lampu'),
                onPressed:
                    unavailable ? null : () => _controller.toggleTorch(),
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
              );
            },
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final canSwitch = (state.availableCameras ?? 2) >= 2;
              return IconButton(
                tooltip: canSwitch ? 'Ganti kamera' : 'Kamera tunggal',
                onPressed:
                    canSwitch ? () => _controller.switchCamera() : null,
                icon: const Icon(Icons.cameraswitch_rounded),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kamera tidak tersedia / izin ditolak.\n$error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => SystemChannels.platform
                            .invokeMethod('SystemNavigator.pop'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Tutup'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Container(decoration: const _ScannerOverlay()),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                if (_lastRaw != null && _lastRaw!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Terakhir: ${_lastRaw!}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Arahkan ke QR/Barcode dalam kotak',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.8),
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

class _ScannerOverlay extends Decoration {
  const _ScannerOverlay();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _ScannerOverlayPainter();
}

class _ScannerOverlayPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size ?? Size.zero;
    final rect = offset & size;

    final cutoutSize = Size(rect.width * 0.75, rect.width * 0.75);
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
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cutout, borderPaint);

    canvas.restore();
  }
}
