import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/snackbar_helper.dart';

/// Shows a crop dialog and returns the cropped [File], or null if cancelled.
Future<File?> showImageCropDialog(BuildContext context, File imageFile) {
  return showDialog<File>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ImageCropDialog(imageFile: imageFile),
  );
}

class _ImageCropDialog extends StatefulWidget {
  final File imageFile;
  const _ImageCropDialog({required this.imageFile});

  @override
  State<_ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<_ImageCropDialog> {
  final _cropController = CropController();
  Uint8List? _imageBytes;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      // Decode to check size and resize if too large (prevents crash)
      final codec = await instantiateImageCodec(bytes, targetWidth: 2048);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();

      if (mounted && byteData != null) {
        setState(() => _imageBytes = byteData.buffer.asUint8List());
      } else if (mounted) {
        // Fallback: use original bytes
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      debugPrint('⚠️ Load image for crop: $e');
      // Fallback: try original bytes
      try {
        final bytes = await widget.imageFile.readAsBytes();
        if (mounted) setState(() => _imageBytes = bytes);
      } catch (_) {
        if (mounted) Navigator.pop(context, widget.imageFile);
      }
    }
  }

  Future<void> _onCropped(Uint8List croppedData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final croppedFile = File('${tempDir.path}/$fileName');
      await croppedFile.writeAsBytes(croppedData);
      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCropping = false);
        showErrorSnackBar(context, 'Ошибка обрезки: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 500,
        height: 550,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: cs.outline.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF8B5CF6)],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.crop_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Обрезка изображения',
                            style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                        Text(
                            'Переместите и масштабируйте для нужного вида',
                            style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isCropping ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),

            // Crop area
            Expanded(
              child: _imageBytes == null
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        child: Crop(
                          controller: _cropController,
                          image: _imageBytes!,
                          aspectRatio: 1.0,
                          initialSize: 0.8,
                          withCircleUi: false,
                          baseColor: cs.surface,
                          maskColor:
                              Colors.black.withValues(alpha: 0.6),
                          cornerDotBuilder: (size, edgeAlignment) =>
                              Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                          onCropped: _onCropped,
                        ),
                      ),
                    ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: cs.outline.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  // Use original
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCropping
                          ? null
                          : () =>
                              Navigator.pop(context, widget.imageFile),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd),
                        ),
                      ),
                      child: Text('Без обрезки',
                          style: AppTypography.labelLarge.copyWith(
                              color: cs.onSurface
                                  .withValues(alpha: 0.7))),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Crop & save
                  Expanded(
                    flex: 2,
                    child: TEButton(
                      onPressed: _isCropping
                          ? () {}
                          : () {
                              setState(() => _isCropping = true);
                              _cropController.crop();
                            },
                      isLoading: _isCropping,
                      label: 'Применить',
                      icon: Icons.check_rounded,
                      isExpanded: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
