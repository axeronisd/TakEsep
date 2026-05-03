import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

/// Opens a full-screen dark barcode scanner.
/// Returns the scanned barcode string, or null if cancelled.
///
/// Usage:
/// ```dart
/// final barcode = await openScanner(context);
/// if (barcode != null) { /* process barcode */ }
/// ```
Future<String?> openScanner(BuildContext context) async {
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _ScannerScreen(),
    ),
  );

  if (result != null && result != '-1' && result.isNotEmpty) {
    return result;
  }
  return null;
}

/// Custom full-screen dark-themed barcode scanner screen.
class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _hasScanned = true;
    Navigator.pop(context, barcode.rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera preview (fills entire screen) ───
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) {
              String msg;
              switch (error.errorCode) {
                case MobileScannerErrorCode.permissionDenied:
                  msg =
                      'Разрешение на использование камеры отклонено.\n\nОткройте Настройки → Приложения → TakEsep → Камера → Разрешить';
                  break;
                case MobileScannerErrorCode.unsupported:
                  msg = 'Камера не поддерживается на этом устройстве';
                  break;
                default:
                  msg =
                      'Ошибка камеры: ${error.errorDetails?.message ?? error.errorCode.name}';
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Назад'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ─── Dark overlay with cutout ───
          _ScannerOverlay(),

          // ─── Top bar ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text('Сканер',
                        style: AppTypography.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        )),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _torchOn ? AppColors.warning : Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        _controller.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Bottom hint ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Наведите камеру на штрихкод',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark overlay with a transparent rectangular cutout in the center.
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Cutout size — 75% of screen width, capped at 300
        final cutoutW = (width * 0.75).clamp(200.0, 300.0);
        final cutoutH = cutoutW * 0.55; // slightly shorter than square
        final left = (width - cutoutW) / 2;
        final top = (height - cutoutH) / 2 - 30; // slightly above center

        return CustomPaint(
          size: Size(width, height),
          painter: _OverlayPainter(
            cutoutRect: Rect.fromLTWH(left, top, cutoutW, cutoutH),
          ),
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent dark overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    // Draw full-screen overlay with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Draw corner brackets on the cutout
    final bracketPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final r = cutoutRect;
    const len = 24.0;
    const rad = 16.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.top + len)
        ..lineTo(r.left, r.top + rad)
        ..quadraticBezierTo(r.left, r.top, r.left + rad, r.top)
        ..lineTo(r.left + len, r.top),
      bracketPaint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(r.right - len, r.top)
        ..lineTo(r.right - rad, r.top)
        ..quadraticBezierTo(r.right, r.top, r.right, r.top + rad)
        ..lineTo(r.right, r.top + len),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.bottom - len)
        ..lineTo(r.left, r.bottom - rad)
        ..quadraticBezierTo(r.left, r.bottom, r.left + rad, r.bottom)
        ..lineTo(r.left + len, r.bottom),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(r.right - len, r.bottom)
        ..lineTo(r.right - rad, r.bottom)
        ..quadraticBezierTo(r.right, r.bottom, r.right, r.bottom - rad)
        ..lineTo(r.right, r.bottom - len),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.cutoutRect != cutoutRect;
}
