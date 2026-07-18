import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/features/downloads/presentation/widgets/download_button.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/core/widgets/app_image.dart';

class SeriesDownloadsScreen extends ConsumerStatefulWidget {
  final String seriesId;
  final String showTitle;

  const SeriesDownloadsScreen({
    Key? key,
    required this.seriesId,
    required this.showTitle,
  }) : super(key: key);

  @override
  ConsumerState<SeriesDownloadsScreen> createState() => _SeriesDownloadsScreenState();
}

class _SeriesDownloadsScreenState extends ConsumerState<SeriesDownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    final downloadManager = ref.watch(downloadManagerProvider);
    // the ListenableBuilder handles rebuilding when download progress updates

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.showTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: downloadManager,
        builder: (context, _) {
          final allDownloads = downloadManager.sortedItems;
          final episodes = allDownloads.where((item) => item.seriesId == widget.seriesId).toList();
          episodes.sort((a, b) {
            final sCompare = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
            if (sCompare != 0) return sCompare;
            return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
          });
          
          return episodes.isEmpty
              ? _buildEmptyState()
              : _buildDownloadsList(episodes);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No episodes found',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'All downloaded episodes for this show have been deleted.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back', style: TextStyle(color: AppColors.netflixRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList(List<DownloadItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final progress = item.progress;
        final isCompleted = item.overallStatus == DownloadStatus.completed;
        
        final tempMovie = Movie(
          id: item.mediaId,
          title: item.title,
          poster: item.posterUrl,
          backdrop: item.backdropUrl,
          type: item.type,
          seasonNumber: item.seasonNumber,
          episodeNumber: item.episodeNumber,
        );

        return Dismissible(
          key: Key(item.mediaId),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: AppColors.backgroundLight,
                  title: const Text('Delete Episode', style: TextStyle(color: Colors.white)),
                  content: Text('Are you sure you want to delete "${item.title}"? This cannot be undone.',
                      style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.netflixRed)),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            ref.read(downloadManagerProvider).deleteDownload(item.mediaId);
            // If this was the last episode, pop the screen
            if (items.length <= 1) {
              if (mounted) context.pop();
            }
          },
          child: InkWell(
            onTap: isCompleted ? () {
              context.push(RouteNames.watchPath(item.mediaId));
            } : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 120,
                      height: 70,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(
                            imageUrl: item.stillUrl ?? item.backdropUrl ?? item.posterUrl ?? '',
                            localPath: item.localStillPath ?? item.localBackdropPath ?? item.localPosterPath,
                            fit: BoxFit.cover,
                          ),
                          if (isCompleted)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                              ),
                            ),
                          if (!isCompleted)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        '${(progress * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: Colors.transparent,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (item.seasonNumber != null)
                          Text(
                            'S${item.seasonNumber} E${item.episodeNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              item.formattedTotalSize,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            if (item.parts.length > 1) ...[
                              const Text(' • ', style: TextStyle(color: Colors.white24)),
                              Text(
                                '${item.completedPartCount}/${item.parts.length} Parts',
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Download action button
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: DownloadButton(movie: tempMovie),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
