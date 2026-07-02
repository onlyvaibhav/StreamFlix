import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';

class NavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      extendBody: true, // Let screens flow behind bottom bar for edge-to-edge
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            height: 70,
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
              currentIndex: navigationShell.currentIndex,
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
                  icon: Icon(Icons.search_rounded, size: 24),
                  activeIcon: Icon(Icons.search_rounded, size: 24, color: AppColors.netflixRed),
                  label: 'Search',
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
