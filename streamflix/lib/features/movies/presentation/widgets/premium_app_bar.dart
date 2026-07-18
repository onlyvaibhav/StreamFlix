import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/netflix_avatar.dart';

import 'package:hive_flutter/hive_flutter.dart';

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

    final user = Hive.box('authBox').get('user') as Map?;
    final firstName = user?['firstName'] ?? 'Guest';
    final nameStr = firstName.toString().split(' ').first;

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
                  // Left: Dynamic Greeting
                  Expanded(
                    child: Text(
                      'StreamFlix',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE50914), // Netflix Red
                        letterSpacing: -1.0,
                      ),
                      maxLines: 1,
                    ),
                  ),
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
                  // Dynamic avatar based on first letter
                  GestureDetector(
                    onTap: () {
                      context.push('/profile'); // or RouteNames.profile if it exists
                    },
                    child: NetflixAvatar(
                      name: nameStr,
                      size: 34,
                      useNetflixFace: true,
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
