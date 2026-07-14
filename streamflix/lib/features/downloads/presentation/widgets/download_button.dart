import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';

class DownloadButton extends ConsumerWidget {
  final Movie movie;
  final List<SplitPart>? resolvedParts;
  final bool compact; // If true, shows just the icon. If false, shows icon + text (for detail page)

  const DownloadButton({
    super.key,
    required this.movie,
    this.resolvedParts,
    this.compact = false,
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

        switch (status) {
          case DownloadStatus.queued:
            return _buildProgressState(context, manager, null);
          case DownloadStatus.downloading:
            return _buildProgressState(context, manager, downloadItem.progress);
          case DownloadStatus.paused:
            return _buildPausedState(context, manager);
          case DownloadStatus.completed:
            return _buildCompletedState(context, manager);
          case DownloadStatus.failed:
            return _buildFailedState(context, manager);
        }
      },
    );
  }

  Widget _buildIdleState(BuildContext context, DownloadManager manager) {
    if (compact) {
      return IconButton(
        icon: const Icon(Icons.download_rounded, color: Colors.white70),
        onPressed: () => _enqueue(manager),
        tooltip: 'Download',
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _enqueue(manager),
      icon: const Icon(Icons.download_rounded),
      label: const Text('Download'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildProgressState(BuildContext context, DownloadManager manager, double? progress) {
    if (compact) {
      return IconButton(
        icon: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const Icon(Icons.stop_rounded, size: 14, color: Colors.white),
          ],
        ),
        onPressed: () => _pause(manager),
        tooltip: 'Pause Download',
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _pause(manager),
      icon: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 2,
          color: Colors.white,
          backgroundColor: Colors.white24,
        ),
      ),
      label: Text(progress != null ? '${(progress * 100).toInt()}%' : 'Queued'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPausedState(BuildContext context, DownloadManager manager) {
    if (compact) {
      return IconButton(
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        onPressed: () => _resume(manager),
        tooltip: 'Resume Download',
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _resume(manager),
      icon: const Icon(Icons.pause_rounded),
      label: const Text('Paused'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCompletedState(BuildContext context, DownloadManager manager) {
    if (compact) {
      return IconButton(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
        onPressed: () => _promptDelete(context, manager),
        tooltip: 'Downloaded',
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _promptDelete(context, manager),
      icon: const Icon(Icons.check_rounded, color: Colors.green),
      label: const Text('Downloaded'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFailedState(BuildContext context, DownloadManager manager) {
    if (compact) {
      return IconButton(
        icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        onPressed: () => _resume(manager),
        tooltip: 'Retry Download',
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _resume(manager),
      icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
      label: const Text('Retry'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
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
        backgroundColor: Colors.grey[900],
        title: const Text('Remove Download?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove this download from your device?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              manager.deleteDownload(movie.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
