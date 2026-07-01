import 'dart:async';
import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/widgets/hero_banner_slide.dart';
import 'package:streamflix/features/movies/presentation/widgets/page_indicator.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';

class HeroBanner extends StatefulWidget {
  final List<Movie> movies;
  final Duration rotationInterval;

  const HeroBanner({
    super.key,
    required this.movies,
    this.rotationInterval = const Duration(seconds: 8),
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoRotation();
  }

  void _startAutoRotation() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.rotationInterval, (timer) {
      if (!mounted) return;
      _nextPage();
    });
  }

  void _nextPage() {
    setState(() {
      _currentPage = (_currentPage + 1) % widget.movies.length;
    });
  }

  void _prevPage() {
    setState(() {
      _currentPage = (_currentPage - 1 + widget.movies.length) % widget.movies.length;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height * 0.48; // Cinematic 48% of viewport height

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Smooth cross-fade transition on slide change
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              _timer?.cancel(); // pause auto-rotation momentarily
              if (details.primaryVelocity! < 0) {
                _nextPage();
              } else if (details.primaryVelocity! > 0) {
                _prevPage();
              }
              _startAutoRotation(); // resume auto rotation
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: HeroBannerSlide(
                key: ValueKey<int>(_currentPage),
                movie: widget.movies[_currentPage],
                height: height,
              ),
            ),
          ),

          // Page indicators
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.movies.length,
                (index) => PageIndicator(
                  isActive: index == _currentPage,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroBannerSkeleton extends StatelessWidget {
  const HeroBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.48;

    return ShimmerLoading(
      child: Container(
        height: height,
        color: AppColors.backgroundLight,
      ),
    );
  }
}
