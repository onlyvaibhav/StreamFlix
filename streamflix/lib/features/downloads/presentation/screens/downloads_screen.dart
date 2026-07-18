import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/features/downloads/presentation/widgets/download_button.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/core/widgets/app_image.dart';

class DownloadGroup {
  final String id;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? localPosterPath;
  final String? localBackdropPath;
  final bool isTvShow;
  final List<DownloadItem> items;
  
  DownloadGroup({
    required this.id,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.localPosterPath,
    this.localBackdropPath,
    required this.isTvShow,
    required this.items,
  });
}

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    final downloadManager = ref.watch(downloadManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go(RouteNames.search),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: downloadManager,
        builder: (context, _) {
          final downloads = downloadManager.sortedItems;
          return downloads.isEmpty
              ? _buildEmptyState()
              : _buildDownloadsList(downloads);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 60,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Downloads Yet',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 12),
            const Text(
              'Movies and TV shows you download will appear here for offline viewing.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Find Something to Download',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DownloadGroup> _groupDownloads(List<DownloadItem> items) {
    final groups = <String, DownloadGroup>{};
    for (final item in items) {
      if (item.type == 'episode' && item.seriesId != null) {
        final seriesId = item.seriesId!;
        if (!groups.containsKey(seriesId)) {
          groups[seriesId] = DownloadGroup(
            id: seriesId,
            title: item.showTitle ?? item.title,
            posterUrl: item.posterUrl,
            backdropUrl: item.backdropUrl,
            localPosterPath: item.localPosterPath,
            localBackdropPath: item.localBackdropPath,
            isTvShow: true,
            items: [],
          );
        }
        groups[seriesId]!.items.add(item);
      } else {
        groups[item.mediaId] = DownloadGroup(
          id: item.mediaId,
          title: item.title,
          posterUrl: item.posterUrl,
          backdropUrl: item.backdropUrl,
          isTvShow: false,
          items: [item],
        );
      }
    }
    return groups.values.toList();
  }

  Widget _buildDownloadsList(List<DownloadItem> items) {
    final groups = _groupDownloads(items);
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        if (group.isTvShow) {
          return _buildTvShowGroup(context, group);
        } else {
          return _buildMovieItem(context, group.items.first);
        }
      },
    );
  }

  Widget _buildTvShowGroup(BuildContext context, DownloadGroup group) {
    final totalBytes = group.items.fold<int>(0, (sum, item) => sum + item.totalSizeBytes);
    final formattedSize = (totalBytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
    
    return Dismissible(
      key: Key('group_${group.id}'),
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
              title: const Text('Delete Show', style: TextStyle(color: Colors.white)),
              content: Text('Are you sure you want to delete all downloaded episodes of "${group.title}"? This cannot be undone.',
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
        for (final item in group.items) {
          ref.read(downloadManagerProvider).deleteDownload(item.mediaId);
        }
      },
      child: InkWell(
        onTap: () {
          context.push(
            Uri(
              path: RouteNames.seriesDownloadsPath(group.id),
              queryParameters: {'showTitle': group.title},
            ).toString()
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 120,
                  height: 70,
                  child: AppImage(
                    imageUrl: group.backdropUrl ?? group.posterUrl ?? '',
                    localPath: group.localBackdropPath ?? group.localPosterPath,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${group.items.length} Episodes • $formattedSize',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieItem(BuildContext context, DownloadItem item) {
    final progress = item.progress;
    final isCompleted = item.overallStatus == DownloadStatus.completed;
    
    // Mock a Movie object to pass to the DownloadButton
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
              title: const Text('Delete Download', style: TextStyle(color: Colors.white)),
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
                    if (item.type == 'episode' && item.seasonNumber != null)
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
              
              const SizedBox(width: 8),
              
              // Action Button
              DownloadButton(movie: tempMovie),
            ],
          ),
        ),
      ),
    );
  }
}
