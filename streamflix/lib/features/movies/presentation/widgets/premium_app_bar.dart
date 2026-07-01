import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';

class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double scrollOffset;

  const PremiumAppBar({
    super.key,
    required this.scrollOffset,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    // Transition background color from transparent to true dark background
    final double progress = (scrollOffset / 180.0).clamp(0.0, 1.0);
    final double blurSigma = progress * 12.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.65 + (progress * 0.3)),
                Colors.black.withValues(alpha: progress * 0.88),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 60.0,
              child: Row(
                children: [
                  // Left: StreamFlix bold text Logo
                  Text(
                    'STREAMFLIX',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.netflixRed,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // Right actions
                  IconButton(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: 'Search catalog',
                    onPressed: () {
                      context.push(RouteNames.search);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Decorative Netflix-style avatar
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(4),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://upload.wikimedia.org/wikipedia/commons/0/0b/Netflix-avatar.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
