import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../theme/akjol_theme.dart';

Future<String?> openTableScanner(BuildContext context) async {
  return await Navigator.push<String>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const TableScannerScreen(),
    ),
  );
}

class TableScannerScreen extends StatefulWidget {
  const TableScannerScreen({super.key});

  @override
  State<TableScannerScreen> createState() => _TableScannerScreenState();
}

class _TableScannerScreenState extends State<TableScannerScreen> {
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

    final scannedVal = barcode.rawValue!;
    _hasScanned = true;
    Navigator.pop(context, scannedVal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) {
              String msg = 'Ошибка камеры: ${error.errorCode.name}';
              if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                msg = 'Разрешение на использование камеры отклонено.';
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Назад'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Cutout overlay
          const _ScannerOverlay(),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Сканирование QR стола',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _torchOn ? AkJolTheme.primary : Colors.white,
                        size: 20,
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

          // Bottom hint
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Наведите камеру на QR-код стола',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final cutoutSize = (width * 0.65).clamp(200.0, 260.0);
        final left = (width - cutoutSize) / 2;
        final top = (height - cutoutSize) / 2 - 20;

        return CustomPaint(
          size: Size(width, height),
          painter: _OverlayPainter(
            cutoutRect: Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
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
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    final bracketPaint = Paint()
      ..color = AkJolTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final r = cutoutRect;
    const len = 20.0; // bracket length
    
    // Top-Left
    canvas.drawPath(Path()..moveTo(r.left, r.top + len)..lineTo(r.left, r.top)..lineTo(r.left + len, r.top), bracketPaint);
    // Top-Right
    canvas.drawPath(Path()..moveTo(r.right - len, r.top)..lineTo(r.right, r.top)..lineTo(r.right, r.top + len), bracketPaint);
    // Bottom-Left
    canvas.drawPath(Path()..moveTo(r.left, r.bottom - len)..lineTo(r.left, r.bottom)..lineTo(r.left + len, r.bottom), bracketPaint);
    // Bottom-Right
    canvas.drawPath(Path()..moveTo(r.right - len, r.bottom)..lineTo(r.right, r.bottom)..lineTo(r.right, r.bottom - len), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
