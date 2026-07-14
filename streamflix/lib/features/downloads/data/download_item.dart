/// Data models for the offline download registry.
///
/// Single-part and multi-part media share the same model — a single-part
/// movie simply has a `parts` list of length 1.

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

enum DownloadPartStatus {
  queued,
  downloading,
  completed,
  failed,
}

/// Represents a single downloadable part (file) of a media item.
class DownloadPart {
  int partIndex;
  DownloadPartStatus status;
  String filePath;
  int sizeBytes;
  int downloadedBytes;
  String fileId; // Original Telegram file ID for building download URL

  DownloadPart({
    required this.partIndex,
    this.status = DownloadPartStatus.queued,
    required this.filePath,
    required this.sizeBytes,
    this.downloadedBytes = 0,
    required this.fileId,
  });

  Map<String, dynamic> toJson() => {
    'partIndex': partIndex,
    'status': status.name,
    'filePath': filePath,
    'sizeBytes': sizeBytes,
    'downloadedBytes': downloadedBytes,
    'fileId': fileId,
  };

  factory DownloadPart.fromJson(Map<String, dynamic> json) => DownloadPart(
    partIndex: json['partIndex'] as int,
    status: DownloadPartStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DownloadPartStatus.queued,
    ),
    filePath: json['filePath'] as String,
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    downloadedBytes: json['downloadedBytes'] as int? ?? 0,
    fileId: json['fileId'] as String,
  );
}

/// Represents one media download — movie or episode.
/// Multi-part media has multiple entries in `parts`.
class DownloadItem {
  final String mediaId;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String type; // 'movie' | 'episode'
  final String? seriesId; // showTmdbId for TV episodes
  final String? showTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  DownloadStatus overallStatus;
  int totalSizeBytes;
  int downloadedBytes;
  DateTime? downloadedAt;
  List<DownloadPart> parts;

  DownloadItem({
    required this.mediaId,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    required this.type,
    this.seriesId,
    this.showTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.overallStatus = DownloadStatus.queued,
    this.totalSizeBytes = 0,
    this.downloadedBytes = 0,
    this.downloadedAt,
    required this.parts,
  });

  /// Aggregate downloaded bytes from all parts.
  int get aggregateDownloadedBytes =>
      parts.fold(0, (sum, p) => sum + p.downloadedBytes);

  /// Aggregate total size from all parts.
  int get aggregateTotalSizeBytes =>
      parts.fold(0, (sum, p) => sum + p.sizeBytes);

  /// Progress as a fraction 0.0–1.0.
  double get progress {
    final total = aggregateTotalSizeBytes;
    if (total <= 0) return 0.0;
    return (aggregateDownloadedBytes / total).clamp(0.0, 1.0);
  }

  /// How many parts are completed.
  int get completedPartCount =>
      parts.where((p) => p.status == DownloadPartStatus.completed).length;

  /// Whether all parts are completed.
  bool get isFullyDownloaded =>
      parts.isNotEmpty && parts.every((p) => p.status == DownloadPartStatus.completed);

  /// Human-readable size (e.g. "1.5 GB").
  String get formattedTotalSize => formatBytes(aggregateTotalSizeBytes);

  /// Human-readable downloaded size.
  String get formattedDownloadedSize => formatBytes(aggregateDownloadedBytes);

  Map<String, dynamic> toJson() => {
    'mediaId': mediaId,
    'title': title,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'type': type,
    'seriesId': seriesId,
    'showTitle': showTitle,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'overallStatus': overallStatus.name,
    'totalSizeBytes': aggregateTotalSizeBytes,
    'downloadedBytes': aggregateDownloadedBytes,
    'downloadedAt': downloadedAt?.toIso8601String(),
    'parts': parts.map((p) => p.toJson()).toList(),
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    mediaId: json['mediaId'] as String,
    title: json['title'] as String,
    posterUrl: json['posterUrl'] as String?,
    backdropUrl: json['backdropUrl'] as String?,
    type: json['type'] as String? ?? 'movie',
    seriesId: json['seriesId'] as String?,
    showTitle: json['showTitle'] as String?,
    seasonNumber: json['seasonNumber'] as int?,
    episodeNumber: json['episodeNumber'] as int?,
    overallStatus: DownloadStatus.values.firstWhere(
      (e) => e.name == json['overallStatus'],
      orElse: () => DownloadStatus.queued,
    ),
    totalSizeBytes: json['totalSizeBytes'] as int? ?? 0,
    downloadedBytes: json['downloadedBytes'] as int? ?? 0,
    downloadedAt: json['downloadedAt'] != null
        ? DateTime.tryParse(json['downloadedAt'] as String)
        : null,
    parts: (json['parts'] as List<dynamic>?)
            ?.map((p) => DownloadPart.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [],
  );

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${suffixes[i]}';
  }
}
