import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:streamflix/core/config/app_config.dart';
import 'package:streamflix/core/network/local_loopback_server.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';

/// Maximum number of downloads running concurrently across the entire queue.
const int _kMaxConcurrentDownloads = 2;

/// Maximum retry attempts per part before marking it as failed.
const int _kMaxRetryAttempts = 3;

/// DownloadManager — singleton ChangeNotifier that owns the download queue,
/// persists state to `downloads.json`, and drives dio downloads.
class DownloadManager extends ChangeNotifier {
  // ─── Singleton ───────────────────────────────────────────
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  // ─── State ───────────────────────────────────────────────
  final Map<String, DownloadItem> _items = {};
  bool _loaded = false;
  String? _storageDir;

  /// Active CancelTokens keyed by `mediaId:partIndex`.
  final Map<String, CancelToken> _cancelTokens = {};

  /// Number of downloads currently in-flight.
  int _activeDownloads = 0;

  /// Dedicated Dio instance for downloads (long timeout, no JSON headers).
  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 30),
    // Auth header still needed for the backend
    headers: {
      'Accept': '*/*',
    },
  ));

  // ─── Public API: Read State ──────────────────────────────

  /// All download items.
  List<DownloadItem> get items => _items.values.toList();

  /// Items sorted by most recent download first.
  List<DownloadItem> get sortedItems {
    final list = _items.values.toList();
    list.sort((a, b) {
      // Active downloads first, then by downloadedAt descending
      final aActive = a.overallStatus == DownloadStatus.downloading ||
          a.overallStatus == DownloadStatus.queued;
      final bActive = b.overallStatus == DownloadStatus.downloading ||
          b.overallStatus == DownloadStatus.queued;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      final aDate = a.downloadedAt ?? DateTime(1970);
      final bDate = b.downloadedAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  /// Get a specific download, or null.
  DownloadItem? getDownload(String mediaId) => _items[mediaId];

  /// Whether a media item is downloaded and ready for offline playback.
  bool isDownloaded(String mediaId) =>
      _items[mediaId]?.overallStatus == DownloadStatus.completed;

  /// Whether a media item is currently being downloaded or queued.
  bool isActive(String mediaId) {
    final item = _items[mediaId];
    if (item == null) return false;
    return item.overallStatus == DownloadStatus.downloading ||
        item.overallStatus == DownloadStatus.queued;
  }

  /// Total bytes used by all completed + partial downloads.
  int get totalStorageUsed =>
      _items.values.fold(0, (sum, item) => sum + item.aggregateDownloadedBytes);

  // ─── Initialization ──────────────────────────────────────

  /// Load the download registry from disk. Call once at app start.
  Future<void> init() async {
    if (_loaded) return;

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        debugPrint('⚠️ DownloadManager: External storage directory not available');
        _loaded = true;
        return;
      }
      _storageDir = dir.path;

      // Ensure downloads subdirectory exists
      final downloadsDir = Directory('$_storageDir/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Load registry
      final registryFile = File('$_storageDir/downloads.json');
      if (await registryFile.exists()) {
        final content = await registryFile.readAsString();
        final Map<String, dynamic> registry = jsonDecode(content);
        _items.clear();
        for (final entry in registry.entries) {
          try {
            _items[entry.key] =
                DownloadItem.fromJson(entry.value as Map<String, dynamic>);
          } catch (e) {
            debugPrint('⚠️ DownloadManager: Failed to parse entry ${entry.key}: $e');
          }
        }
        debugPrint('📥 DownloadManager: Loaded ${_items.length} download entries');
      }
    } catch (e) {
      debugPrint('⚠️ DownloadManager: Init failed: $e');
    }

    _loaded = true;
    notifyListeners();

    // Resume any downloads that were in-progress when the app was killed
    _resumeIncompleteDownloads();
  }

  // ─── Public API: Actions ─────────────────────────────────

  /// Enqueue a movie or episode for download.
  ///
  /// For multi-part media, pass the pre-resolved [parts] list.
  /// For single-part, pass null or empty — one part will be created
  /// using the movie's own id and size.
  Future<void> enqueue(Movie movie, {List<SplitPart>? parts}) async {
    if (_storageDir == null) {
      debugPrint('⚠️ DownloadManager: Storage directory not available');
      return;
    }

    final mediaId = movie.id;

    // Don't re-enqueue if already exists and isn't failed
    if (_items.containsKey(mediaId)) {
      final existing = _items[mediaId]!;
      if (existing.overallStatus == DownloadStatus.completed) {
        debugPrint('📥 Already downloaded: ${movie.title}');
        return;
      }
      if (existing.overallStatus != DownloadStatus.failed) {
        debugPrint('📥 Already in queue: ${movie.title}');
        return;
      }
      // Re-enqueue failed downloads: reset parts to queued
      for (final part in existing.parts) {
        if (part.status == DownloadPartStatus.failed) {
          part.status = DownloadPartStatus.queued;
          part.downloadedBytes = 0;
        }
      }
      existing.overallStatus = DownloadStatus.queued;
      await _persist();
      notifyListeners();
      _processQueue();
      return;
    }

    // Build parts list
    final downloadParts = <DownloadPart>[];
    final resolvedParts = (parts != null && parts.isNotEmpty) ? parts : null;

    if (resolvedParts != null) {
      for (int i = 0; i < resolvedParts.length; i++) {
        final sp = resolvedParts[i];
        final fileId = sp.fileId ?? mediaId;
        final partPath = _buildPartPath(mediaId, i);
        downloadParts.add(DownloadPart(
          partIndex: i,
          filePath: partPath,
          sizeBytes: sp.size ?? 0,
          fileId: fileId,
        ));
      }
    } else {
      // Single-part
      downloadParts.add(DownloadPart(
        partIndex: 0,
        filePath: _buildPartPath(mediaId, 0),
        sizeBytes: movie.size ?? 0,
        fileId: mediaId,
      ));
    }

    final isTv = movie.type == 'tv' || movie.tv != null;

    final item = DownloadItem(
      mediaId: mediaId,
      title: movie.title,
      posterUrl: movie.poster,
      backdropUrl: movie.backdrop,
      type: isTv ? 'episode' : 'movie',
      seriesId: isTv ? movie.tv?.showTmdbId.toString() : null,
      showTitle: isTv ? movie.tv?.showTitle : null,
      seasonNumber: isTv ? (movie.tv?.seasonNumber ?? movie.seasonNumber) : null,
      episodeNumber: isTv ? (movie.tv?.episodeNumber ?? movie.episodeNumber) : null,
      parts: downloadParts,
    );

    _items[mediaId] = item;
    await _persist();
    notifyListeners();

    debugPrint('📥 Enqueued download: ${movie.title} (${downloadParts.length} parts)');
    _processQueue();
  }

  /// Pause a download.
  Future<void> pauseDownload(String mediaId) async {
    final item = _items[mediaId];
    if (item == null) return;

    // Cancel any active dio requests for this item
    for (final part in item.parts) {
      final key = '$mediaId:${part.partIndex}';
      _cancelTokens[key]?.cancel('User paused download');
      _cancelTokens.remove(key);
    }

    item.overallStatus = DownloadStatus.paused;
    for (final part in item.parts) {
      if (part.status == DownloadPartStatus.downloading) {
        part.status = DownloadPartStatus.queued;
      }
    }

    await _persist();
    notifyListeners();
    debugPrint('⏸️ Paused download: ${item.title}');
  }

  /// Resume a paused or failed download.
  Future<void> resumeDownload(String mediaId) async {
    final item = _items[mediaId];
    if (item == null) return;

    if (item.overallStatus == DownloadStatus.paused ||
        item.overallStatus == DownloadStatus.failed) {
      item.overallStatus = DownloadStatus.queued;
      for (final part in item.parts) {
        if (part.status == DownloadPartStatus.failed) {
          part.status = DownloadPartStatus.queued;
        }
      }
      await _persist();
      notifyListeners();
      _processQueue();
      debugPrint('▶️ Resumed download: ${item.title}');
    }
  }

  /// Cancel and remove a download entirely.
  Future<void> cancelDownload(String mediaId) async {
    final item = _items[mediaId];
    if (item == null) return;

    // Cancel active downloads
    for (final part in item.parts) {
      final key = '$mediaId:${part.partIndex}';
      _cancelTokens[key]?.cancel('User cancelled download');
      _cancelTokens.remove(key);
    }

    // Delete partial files
    for (final part in item.parts) {
      try {
        final file = File(part.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete part file: $e');
      }
    }

    _items.remove(mediaId);
    await _persist();
    notifyListeners();
    debugPrint('🗑️ Cancelled download: ${item.title}');
  }

  /// Delete a completed download, freeing disk space.
  Future<int> deleteDownload(String mediaId) async {
    final item = _items[mediaId];
    if (item == null) return 0;

    int freedBytes = 0;

    // Cancel any active parts just in case
    for (final part in item.parts) {
      final key = '$mediaId:${part.partIndex}';
      _cancelTokens[key]?.cancel('Deleted');
      _cancelTokens.remove(key);
    }

    // Delete files
    for (final part in item.parts) {
      try {
        final file = File(part.filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          freedBytes += stat.size;
          await file.delete();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete part file: $e');
      }
    }

    _items.remove(mediaId);
    await _persist();
    notifyListeners();
    debugPrint('🗑️ Deleted download: ${item.title}, freed ${DownloadItem.formatBytes(freedBytes)}');
    return freedBytes;
  }

  /// Check available device storage.
  Future<int> getAvailableStorage() async {
    try {
      if (_storageDir == null) return 0;
      final stat = await Directory(_storageDir!).stat();
      // FileStat doesn't give free space on Android — use a different approach
      // Use the storage info from the filesystem
      final result = await Process.run('df', [_storageDir!]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // Available is in 1K blocks
            return int.tryParse(parts[3]) ?? 0;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get available storage: $e');
    }
    // Fallback: return a large number to avoid blocking downloads
    return 1024 * 1024 * 1024 * 10; // 10GB fallback
  }

  /// Reconcile registry vs disk on app start.
  /// Removes orphaned entries and orphaned files.
  Future<void> reconcile() async {
    if (_storageDir == null) return;

    final downloadsDir = Directory('$_storageDir/downloads');
    if (!await downloadsDir.exists()) return;

    // 1. Remove registry entries whose files are all missing
    final entriesToRemove = <String>[];
    for (final entry in _items.entries) {
      final item = entry.value;
      if (item.overallStatus == DownloadStatus.completed) {
        bool anyFileExists = false;
        for (final part in item.parts) {
          if (await File(part.filePath).exists()) {
            anyFileExists = true;
            break;
          }
        }
        if (!anyFileExists) {
          debugPrint('🧹 Reconcile: Removing orphaned registry entry: ${item.title}');
          entriesToRemove.add(entry.key);
        }
      } else if (item.overallStatus == DownloadStatus.downloading ||
                 item.overallStatus == DownloadStatus.queued) {
        // Downloads that were interrupted mid-flight — mark as queued for resume
        item.overallStatus = DownloadStatus.queued;
        for (final part in item.parts) {
          if (part.status == DownloadPartStatus.downloading) {
            part.status = DownloadPartStatus.queued;
            // Update downloadedBytes to match actual file size on disk
            try {
              final file = File(part.filePath);
              if (await file.exists()) {
                part.downloadedBytes = await file.length();
              } else {
                part.downloadedBytes = 0;
              }
            } catch (_) {
              part.downloadedBytes = 0;
            }
          }
        }
      }
    }
    for (final key in entriesToRemove) {
      _items.remove(key);
    }

    // 2. Clean up orphaned files in downloads directory
    try {
      final knownPaths = <String>{};
      for (final item in _items.values) {
        for (final part in item.parts) {
          knownPaths.add(part.filePath);
        }
      }

      await for (final entity in downloadsDir.list()) {
        if (entity is File && !knownPaths.contains(entity.path)) {
          debugPrint('🧹 Reconcile: Removing orphaned file: ${entity.path}');
          try {
            await entity.delete();
          } catch (e) {
            debugPrint('⚠️ Failed to delete orphaned file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Reconcile: Error cleaning orphaned files: $e');
    }

    if (entriesToRemove.isNotEmpty) {
      await _persist();
      notifyListeners();
    }

    debugPrint('🧹 Reconciliation complete. ${_items.length} entries remain.');
  }

  // ─── Download Queue Processor ────────────────────────────

  /// Process the download queue: start downloads up to the concurrency cap.
  void _processQueue() {
    if (_activeDownloads >= _kMaxConcurrentDownloads) return;

    // Find next queued item
    for (final item in _items.values) {
      if (_activeDownloads >= _kMaxConcurrentDownloads) break;
      if (item.overallStatus == DownloadStatus.queued) {
        _startDownload(item);
      }
    }
  }

  /// Resume incomplete downloads (called after init).
  void _resumeIncompleteDownloads() {
    for (final item in _items.values) {
      if (item.overallStatus == DownloadStatus.queued ||
          item.overallStatus == DownloadStatus.downloading) {
        item.overallStatus = DownloadStatus.queued;
      }
    }
    _processQueue();
  }

  /// Start downloading all parts of an item sequentially.
  Future<void> _startDownload(DownloadItem item) async {
    item.overallStatus = DownloadStatus.downloading;
    _activeDownloads++;
    notifyListeners();

    debugPrint('📥 Starting download: ${item.title} (${item.parts.length} parts)');

    bool failed = false;

    for (final part in item.parts) {
      // Skip already-completed parts
      if (part.status == DownloadPartStatus.completed) continue;

      // Check if download was paused/cancelled
      if (item.overallStatus == DownloadStatus.paused) break;

      final success = await _downloadPart(item, part);
      if (!success) {
        failed = true;
        break;
      }
    }

    _activeDownloads--;

    if (item.overallStatus == DownloadStatus.paused) {
      // User paused — don't change status
    } else if (failed) {
      item.overallStatus = DownloadStatus.failed;
    } else if (item.isFullyDownloaded) {
      item.overallStatus = DownloadStatus.completed;
      item.downloadedAt = DateTime.now();
      debugPrint('✅ Download complete: ${item.title}');
    }

    await _persist();
    notifyListeners();

    // Process next in queue
    _processQueue();
  }

  /// Download a single part with retry logic.
  Future<bool> _downloadPart(DownloadItem item, DownloadPart part) async {
    for (int attempt = 1; attempt <= _kMaxRetryAttempts; attempt++) {
      if (item.overallStatus == DownloadStatus.paused) return false;

      part.status = DownloadPartStatus.downloading;
      notifyListeners();

      final cancelToken = CancelToken();
      final tokenKey = '${item.mediaId}:${part.partIndex}';
      _cancelTokens[tokenKey] = cancelToken;

      try {
        // Check if partial file exists for resume
        final partFile = File(part.filePath);
        int existingBytes = 0;
        if (await partFile.exists()) {
          existingBytes = await partFile.length();
          part.downloadedBytes = existingBytes;
        }

        // If the file size is unknown (0), do a HEAD request to get Content-Length
        if (part.sizeBytes <= 0) {
          try {
            final headUrl = 'http://127.0.0.1:${LocalLoopbackServer().port}/stream/${part.fileId}';
            final headResponse = await _dio.head(headUrl, cancelToken: cancelToken);
            final contentLength = headResponse.headers.value('content-length');
            if (contentLength != null) {
              part.sizeBytes = int.tryParse(contentLength) ?? 0;
            }
          } catch (e) {
            debugPrint('⚠️ HEAD request failed for size: $e');
          }
        }

        // If already fully downloaded, skip
        if (existingBytes > 0 && part.sizeBytes > 0 && existingBytes >= part.sizeBytes) {
          part.status = DownloadPartStatus.completed;
          part.downloadedBytes = part.sizeBytes;
          _cancelTokens.remove(tokenKey);
          await _persist();
          notifyListeners();
          debugPrint('⏭️ Part ${part.partIndex} already complete, skipping');
          return true;
        }

        final downloadUrl = 'http://127.0.0.1:${LocalLoopbackServer().port}/stream/${part.fileId}';
        final options = Options(
          responseType: ResponseType.stream,
        );

        // Add Range header for resume
        if (existingBytes > 0) {
          options.headers = {
            'Range': 'bytes=$existingBytes-',
          };
          debugPrint('📥 Resuming part ${part.partIndex} from byte $existingBytes');
        }

        final response = await _dio.get<ResponseBody>(
          downloadUrl,
          options: options,
          cancelToken: cancelToken,
        );

        // Get content length from response
        final contentLengthHeader = response.headers.value('content-length');
        if (contentLengthHeader != null && part.sizeBytes <= 0) {
          final contentRange = response.headers.value('content-range');
          if (contentRange != null) {
            // Parse "bytes start-end/total"
            final match = RegExp(r'bytes \d+-\d+/(\d+)').firstMatch(contentRange);
            if (match != null) {
              part.sizeBytes = int.tryParse(match.group(1)!) ?? 0;
            }
          } else {
            part.sizeBytes = (int.tryParse(contentLengthHeader) ?? 0) + existingBytes;
          }
        }

        // Stream data to file
        final sink = partFile.openWrite(mode: existingBytes > 0 ? FileMode.append : FileMode.write);
        int bytesReceived = existingBytes;

        try {
          await for (final chunk in response.data!.stream) {
            sink.add(chunk);
            bytesReceived += chunk.length;
            part.downloadedBytes = bytesReceived;

            // Throttle UI updates to avoid excessive notifyListeners calls
            // Update UI every ~256KB
            if (bytesReceived % (256 * 1024) < chunk.length) {
              item.downloadedBytes = item.aggregateDownloadedBytes;
              notifyListeners();
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
        }

        // Verify download completed
        part.downloadedBytes = bytesReceived;
        part.status = DownloadPartStatus.completed;
        item.downloadedBytes = item.aggregateDownloadedBytes;
        _cancelTokens.remove(tokenKey);

        await _persist();
        notifyListeners();
        debugPrint('✅ Part ${part.partIndex} complete: ${DownloadItem.formatBytes(bytesReceived)}');
        return true;
      } on DioException catch (e) {
        _cancelTokens.remove(tokenKey);

        if (e.type == DioExceptionType.cancel) {
          debugPrint('⏸️ Part ${part.partIndex} download cancelled');
          return false;
        }

        debugPrint('❌ Part ${part.partIndex} attempt $attempt/$_kMaxRetryAttempts failed: ${e.message}');

        if (attempt < _kMaxRetryAttempts) {
          // Exponential backoff: 2s, 4s, 8s
          final delay = Duration(seconds: 2 * (1 << (attempt - 1)));
          debugPrint('🔄 Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      } catch (e) {
        _cancelTokens.remove(tokenKey);
        debugPrint('❌ Part ${part.partIndex} attempt $attempt/$_kMaxRetryAttempts failed: $e');

        if (attempt < _kMaxRetryAttempts) {
          final delay = Duration(seconds: 2 * (1 << (attempt - 1)));
          await Future.delayed(delay);
        }
      }
    }

    // All attempts exhausted
    part.status = DownloadPartStatus.failed;
    await _persist();
    notifyListeners();
    return false;
  }

  // ─── Persistence ─────────────────────────────────────────

  String _buildPartPath(String mediaId, int partIndex) {
    // Sanitize mediaId for filesystem safety
    final safeId = mediaId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return '$_storageDir/downloads/${safeId}_part$partIndex.mp4';
  }

  Future<void> _persist() async {
    if (_storageDir == null) return;
    try {
      final registryFile = File('$_storageDir/downloads.json');
      final map = <String, dynamic>{};
      for (final entry in _items.entries) {
        map[entry.key] = entry.value.toJson();
      }
      await registryFile.writeAsString(jsonEncode(map));
    } catch (e) {
      debugPrint('⚠️ DownloadManager: Failed to persist registry: $e');
    }
  }
}

// ─── Riverpod Provider ─────────────────────────────────────

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager();
});
