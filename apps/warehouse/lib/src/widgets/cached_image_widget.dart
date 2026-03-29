import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Cached network image widget that persists across sessions (offline support).
/// Replaces Image.network for product/service images everywhere.
class CachedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _defaultPlaceholder(context);
    }

    final image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) =>
          placeholder ?? _loadingPlaceholder(context),
      errorWidget: (_, __, ___) =>
          errorWidget ?? _defaultPlaceholder(context),
      fadeInDuration: const Duration(milliseconds: 200),
      // Cache for 30 days
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _loadingPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image_rounded,
        color: cs.onSurface.withValues(alpha: 0.2),
        size: (width != null && width! < 60) ? 20 : 32,
      ),
    );
  }
}
