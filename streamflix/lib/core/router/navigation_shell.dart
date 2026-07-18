import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/network/connectivity_service.dart';

class NavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              color: AppColors.netflixRed,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                bottom: 8,
              ),
              child: const Text(
                'You are currently offline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          Expanded(child: widget.navigationShell),
        ],
      ),
      extendBody: true, // Let screens flow behind bottom bar for edge-to-edge
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => _onTap(context, index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.netflixRed,
              unselectedItemColor: Colors.white54,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled, size: 24),
                  activeIcon: Icon(Icons.home_filled, size: 24, color: AppColors.netflixRed),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.category_outlined, size: 24),
                  activeIcon: Icon(Icons.category_rounded, size: 24, color: AppColors.netflixRed),
                  label: 'Genres',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.tv_outlined, size: 24),
                  activeIcon: Icon(Icons.tv_rounded, size: 24, color: AppColors.netflixRed),
                  label: 'TV Shows',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.movie_outlined, size: 24),
                  activeIcon: Icon(Icons.movie_rounded, size: 24, color: AppColors.netflixRed),
                  label: 'Movies',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.download_for_offline_outlined, size: 24),
                  activeIcon: Icon(Icons.download_for_offline_rounded, size: 24, color: AppColors.netflixRed),
                  label: 'Downloads',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline, size: 24),
                  activeIcon: Icon(Icons.person_rounded, size: 24, color: AppColors.netflixRed),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
