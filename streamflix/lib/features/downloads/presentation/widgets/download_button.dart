import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';
import 'package:streamflix/core/constants/app_colors.dart';

class DownloadButton extends ConsumerWidget {
  final Movie movie;
  final List<SplitPart>? resolvedParts;

  const DownloadButton({
    super.key,
    required this.movie,
    this.resolvedParts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We listen to the download manager to rebuild when the status changes
    final manager = ref.watch(downloadManagerProvider);
    
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final downloadItem = manager.getDownload(movie.id);
        
        final status = downloadItem?.overallStatus ?? DownloadStatus.queued;
        final isKnown = downloadItem != null;

        if (!isKnown) {
          return _buildIdleState(context, manager);
        }

        Widget child = const SizedBox.shrink();
        switch (status) {
          case DownloadStatus.queued:
            child = _buildQueuedState(context, manager);
            break;
          case DownloadStatus.downloading:
            child = _buildProgressState(context, manager, downloadItem.progress);
            break;
          case DownloadStatus.paused:
            child = _buildPausedState(context, manager);
            break;
          case DownloadStatus.completed:
            child = _buildCompletedState(context, manager);
            break;
          case DownloadStatus.failed:
            child = _buildFailedState(context, manager);
            break;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  Widget _buildIdleState(BuildContext context, DownloadManager manager) {
    return _buildIconWrapper(
      key: const ValueKey('idle'),
      icon: const Icon(Icons.download_rounded, color: AppColors.textSecondary, size: 28),
      onPressed: () => _enqueue(manager),
      tooltip: 'Download',
    );
  }

  Widget _buildQueuedState(BuildContext context, DownloadManager manager) {
    return _buildIconWrapper(
      key: const ValueKey('queued'),
      icon: const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 26),
      onPressed: () => _pause(manager),
      tooltip: 'Queued',
    );
  }

  Widget _buildProgressState(BuildContext context, DownloadManager manager, double? progress) {
    return _buildIconWrapper(
      key: const ValueKey('progress'),
      icon: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              color: AppColors.textPrimary,
              backgroundColor: Colors.white12,
            ),
          ),
          const Icon(Icons.stop_rounded, size: 14, color: AppColors.textPrimary),
        ],
      ),
      onPressed: () => _pause(manager),
      tooltip: 'Pause Download',
    );
  }

  Widget _buildPausedState(BuildContext context, DownloadManager manager) {
    return _buildIconWrapper(
      key: const ValueKey('paused'),
      icon: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.textSecondary, size: 28),
      onPressed: () => _resume(manager),
      tooltip: 'Resume Download',
    );
  }

  Widget _buildCompletedState(BuildContext context, DownloadManager manager) {
    return _buildIconWrapper(
      key: const ValueKey('completed'),
      icon: const Icon(Icons.download_done_rounded, color: AppColors.textPrimary, size: 28),
      onPressed: () => _promptDelete(context, manager),
      tooltip: 'Downloaded',
    );
  }

  Widget _buildFailedState(BuildContext context, DownloadManager manager) {
    return _buildIconWrapper(
      key: const ValueKey('failed'),
      icon: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
      onPressed: () => _resume(manager),
      tooltip: 'Retry Download',
    );
  }

  Widget _buildIconWrapper({
    required Key key,
    required Widget icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }

  void _enqueue(DownloadManager manager) {
    manager.enqueue(movie, parts: resolvedParts);
  }

  void _pause(DownloadManager manager) {
    manager.pauseDownload(movie.id);
  }

  void _resume(DownloadManager manager) {
    manager.resumeDownload(movie.id);
  }

  void _promptDelete(BuildContext context, DownloadManager manager) {
    // To be implemented fully in Phase 4. For now, just a simple dialog.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('Remove Download?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to remove this download from your device?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              manager.deleteDownload(movie.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
