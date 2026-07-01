import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';

class NextEpisodeOverlay extends ConsumerStatefulWidget {
  final Movie nextEpisode;
  final String movieId;

  const NextEpisodeOverlay({
    super.key,
    required this.nextEpisode,
    required this.movieId,
  });

  @override
  ConsumerState<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends ConsumerState<NextEpisodeOverlay> {
  int _secondsLeft = 15;
  Timer? _countdownTimer;
  bool _isCanceled = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _playNext();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _playNext() {
    if (_isCanceled) return;
    _countdownTimer?.cancel();
    ref.read(moviePlayerProvider(widget.movieId).notifier).playNextEpisode();
  }

  void _cancelNext() {
    _countdownTimer?.cancel();
    setState(() {
      _isCanceled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCanceled) return const SizedBox.shrink();

    final seasonNum = widget.nextEpisode.seasonNumber ?? widget.nextEpisode.tv?.seasonNumber ?? 1;
    final epNum = widget.nextEpisode.episodeNumber ?? widget.nextEpisode.tv?.episodeNumber ?? 1;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.slow_motion_video_rounded, color: AppColors.netflixRed, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Next Episode in ${_secondsLeft}s',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _cancelNext,
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.nextEpisode.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Season $seasonNum · Episode $epNum',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Play button
              GestureDetector(
                onTap: _playNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Play Now',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // Cancel button text
              GestureDetector(
                onTap: _cancelNext,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
