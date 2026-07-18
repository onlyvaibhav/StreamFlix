import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:streamflix/core/config/app_config.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/shimmer_box.dart';

/// Cached network image wrapper with loading and error states
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final String? localPath;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.localPath,
  });

  @override
  Widget build(BuildContext context) {
    // Construct full URL if relative path provided
    final baseUrl = AppConfig.v1BaseUrl;
    final path = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '$baseUrl$path';

    Widget image;

    if (localPath != null && localPath!.isNotEmpty && File(localPath!).existsSync()) {
      image = Image.file(
        File(localPath!),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: AppColors.backgroundCard,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.textTertiary,
                size: 48,
              ),
            ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: fullUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width != null && width != double.infinity ? (width! * 2).toInt() : null,
        memCacheHeight: height != null && height != double.infinity ? (height! * 2).toInt() : null,
        placeholder: (context, url) => ShimmerBox(
          width: width,
          height: height,
        ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: AppColors.backgroundCard,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.textTertiary,
                size: 48,
              ),
            ),
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
