import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';

/// Page indicator dot used in banners
class PageIndicator extends StatelessWidget {
  final bool isActive;

  const PageIndicator({
    super.key,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.netflixRed : AppColors.textTertiary,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
