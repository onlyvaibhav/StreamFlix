import 'package:flutter/material.dart';

/// Reusable gradient overlay for backdrops and cards
class GradientOverlay extends StatelessWidget {
  final List<Color> colors;
  final List<double>? stops;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientOverlay({
    super.key,
    required this.colors,
    this.stops,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  /// Bottom-to-top dark gradient (typical for hero banners)
  const GradientOverlay.bottomDark({
    super.key,
  })  : colors = const [
          Color(0x00000000),
          Color(0x80000000),
          Color(0xFF000000), // True cinematic black solid bottom
        ],
        stops = const [0.0, 0.5, 1.0],
        begin = Alignment.topCenter,
        end = Alignment.bottomCenter;

  /// Card hover gradient (used on movie cards)
  const GradientOverlay.card({
    super.key,
  })  : colors = const [
          Color(0x00000000),
          Color(0xCC000000),
        ],
        stops = const [0.5, 1.0],
        begin = Alignment.topCenter,
        end = Alignment.bottomCenter;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}
