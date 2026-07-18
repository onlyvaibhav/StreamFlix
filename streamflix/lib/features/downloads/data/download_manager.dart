import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:streamflix/core/config/app_config.dart';
import 'package:streamflix/core/network/local_loopback_server.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/core/services/download_service_channel.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';
import 'package:flutter/material.dart';
import 'package:streamflix/main.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/router/app_router.dart';
import 'package:streamflix/core/services/download_service_channel.dart';

const int _kMaxConcurrentDownloads = 1;

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

  /// Phase A: Dart-side heartbeat timer for background diagnostics
  Timer? _dartHeartbeatTimer;

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
      final aActive = a.overallStatus == DownloadStatus.downloading ||
          a.overallStatus == DownloadStatus.queued;
      final bActive = b.overallStatus == DownloadStatus.downloading ||
          b.overallStatus == DownloadStatus.queued;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;

      final aFailed = a.overallStatus == DownloadStatus.failed;
      final bFailed = b.overallStatus == DownloadStatus.failed;
      if (aFailed && !bFailed) return -1;
      if (!aFailed && bFailed) return 1;

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

  void _showSnackBar(String message, {bool isError = false}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
      stillUrl: movie.episodeStill,
      type: isTv ? 'episode' : 'movie',
      seriesId: isTv ? movie.tv?.showTmdbId.toString() : null,
      showTitle: isTv ? movie.tv?.showTitle : null,
      seasonNumber: isTv ? (movie.tv?.seasonNumber ?? movie.seasonNumber) : null,
      episodeNumber: isTv ? (movie.tv?.episodeNumber ?? movie.episodeNumber) : null,
      parts: downloadParts,
    );

    // Fetch offline assets (images, metadata, subs) before persisting and queuing
    _showSnackBar('Preparing download... (Fetching metadata & subtitles)');
    await _fetchOfflineAssets(item);

    _items[mediaId] = item;
    await _persist();
    notifyListeners();

    debugPrint('📥 Enqueued download: ${movie.title} (${downloadParts.length} parts)');
    _showSnackBar('Download queued: ${movie.title}');
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
          // No-op
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

  /// Update the real duration of a specific downloaded part (called during offline playback).
  Future<void> updatePartDuration(String mediaId, int partIndex, double duration) async {
    final item = _items[mediaId];
    if (item == null) return;
    
    if (partIndex >= 0 && partIndex < item.parts.length) {
       item.parts[partIndex].duration = duration;
       await _persist();
       debugPrint('💾 Persisted real duration for ${item.title} Part ${partIndex + 1}: ${duration}s');
    }
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
    
    // Resume any downloads that were in-progress when the app was killed
    _resumeIncompleteDownloads();
  }

  // ─── Download Queue Processor ────────────────────────────

  /// Process the download queue: start downloads up to the concurrency cap.
  void _processQueue() {
    // Defensive check to prevent queue from getting stuck permanently
    int actualActive = 0;
    for (final item in _items.values) {
      if (item.overallStatus == DownloadStatus.downloading) {
        actualActive++;
      }
    }
    _activeDownloads = actualActive;

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
    _startDartHeartbeat();
    notifyListeners();

    // Start Android foreground service to prevent process suspension
    DownloadServiceChannel.startService(item.title);

    debugPrint('📥 Starting download: ${item.title} (${item.parts.length} parts)');

    try {
      bool failed = false;
      int currentIndex = 0;
      final List<Future<void>> workers = [];

      Future<void> workerTask() async {
        while (currentIndex < item.parts.length) {
          if (item.overallStatus == DownloadStatus.paused) break;
          final part = item.parts[currentIndex++];
          
          if (part.status == DownloadPartStatus.completed) continue;

          final result = await _downloadPart(item, part);
          if (result == false) {
            failed = true;
          }
        }
      }

      // Process parts sequentially to avoid flood waits
      final workerCount = 1;
      for (int i = 0; i < workerCount; i++) {
        workers.add(workerTask());
      }

      await Future.wait(workers);

      if (item.overallStatus == DownloadStatus.paused) {
        // User paused — don't change status
      } else if (failed) {
        item.overallStatus = DownloadStatus.failed;
        _showSnackBar('Download failed: ${item.title}', isError: true);
      } else if (item.isFullyDownloaded) {
        item.overallStatus = DownloadStatus.completed;
        item.downloadedAt = DateTime.now();
        debugPrint('✅ Download complete: ${item.title}');
        _showSnackBar('Download complete: ${item.title}');
      }

      await _persist();
      notifyListeners();
    } finally {
      _activeDownloads--;
      if (_activeDownloads <= 0) {
        _stopDartHeartbeat();
        DownloadServiceChannel.stopService();
      }
      // Process next in queue
      _processQueue();
    }
  }

  Future<bool?> _downloadPart(DownloadItem item, DownloadPart part) async {
    if (item.overallStatus == DownloadStatus.paused) return null;

    part.status = DownloadPartStatus.downloading;
    notifyListeners();

    final cancelToken = CancelToken();
    final tokenKey = '${item.mediaId}:${part.partIndex}';
    _cancelTokens[tokenKey] = cancelToken;

    final partFile = File(part.filePath);
    int existingBytes = 0;

    if (await partFile.exists()) {
      existingBytes = await partFile.length();
      
      // Rollback truncated append if app crashed mid-write
      if (existingBytes > 0 && part.sizeBytes > 0 && existingBytes < part.sizeBytes) {
        final remainder = existingBytes % (1024 * 1024);
        if (remainder != 0) {
          debugPrint('⚠️ Detected truncated append of $remainder bytes. Rolling back to last 1MB boundary.');
          existingBytes -= remainder;
          final raf = await partFile.open(mode: FileMode.append);
          await raf.truncate(existingBytes);
          await raf.close();
        }
      }
      
      part.downloadedBytes = existingBytes;
      
      // Clean up orphaned chunk files from previous interrupted runs
      try {
         final dir = partFile.parent;
         await for (final entity in dir.list()) {
            if (entity is File && entity.path.startsWith('${partFile.path}.chunk_')) {
               await entity.delete();
            }
         }
      } catch (_) {}
    } else {
      part.downloadedBytes = 0;
      await _persist();
    }

    Map<String, dynamic>? fileLoc;
    try {
      final token = Hive.box('authBox').get('token') as String?;
      final infoRes = await _dio.get(
        '${AppConfig.v1BaseUrl}/api/stream/${part.fileId}/file-info',
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
      if (infoRes.data != null && infoRes.data['fileLocation'] != null) {
        fileLoc = infoRes.data['fileLocation'];
        if (part.sizeBytes <= 0) {
          part.sizeBytes = infoRes.data['fileSize'] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch file info for download: $e');
    }

    if (fileLoc == null) {
      part.status = DownloadPartStatus.failed;
      await _persist();
      notifyListeners();
      return false;
    }

    if (existingBytes > 0 && part.sizeBytes > 0 && existingBytes >= part.sizeBytes) {
      part.status = DownloadPartStatus.completed;
      part.downloadedBytes = part.sizeBytes;
      _cancelTokens.remove(tokenKey);
      await _persist();
      notifyListeners();
      debugPrint('⏭️ Part ${part.partIndex} already complete, skipping');
      return true;
    }

    final raf = await partFile.open(mode: FileMode.append);

    // Dynamic worker throttling
    // Reset worker count to default at the start of each part — flood-wait reductions
    // from previous sessions should not permanently cripple parallelism.
    item.currentWorkerCount = 4;
    int workers = item.currentWorkerCount;
    void onActiveStreamsChanged() {
      if (LocalLoopbackServer().activeStreamCount.value > 0 && workers > 1) {
         workers = 1;
         debugPrint('🍿 Active playback detected, throttling download workers to 1');
         TelegramClientService().setParallelWorkerCount(tokenKey, 1);
      } else if (LocalLoopbackServer().activeStreamCount.value == 0 && workers == 1) {
         workers = item.currentWorkerCount;
         debugPrint('🍿 Playback stopped, restoring download workers to ${item.currentWorkerCount}');
         TelegramClientService().setParallelWorkerCount(tokenKey, item.currentWorkerCount);
      }
    }
    LocalLoopbackServer().activeStreamCount.addListener(onActiveStreamsChanged);
    
    // Initial check
    if (LocalLoopbackServer().activeStreamCount.value > 0) {
      workers = 1;
      debugPrint('🍿 Active playback detected, starting download with 1 worker');
    }

    final completer = Completer<bool?>();
    StreamSubscription? sub;

    cancelToken.whenCancel.then((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    int expectedOffset = existingBytes;
    bool isWriting = false;
    bool jsCompleted = false;

    sub = TelegramClientService().parallelDownloadStream.listen((msg) async {
      try {
        if (msg['mediaId'] != tokenKey) return;
        
        if (msg['type'] == 'parallelChunkResult') {
          final offset = msg['offset'] as int;
          final data = base64Decode(msg['data']);
          
          if (offset == expectedOffset) {
             isWriting = true;
             try {
                 await raf.writeFrom(data);
                 expectedOffset += data.length;
                 
                 // Consume any queued contiguous chunks from disk
                 while (true) {
                    final nextChunkFile = File('${partFile.path}.chunk_$expectedOffset');
                    if (await nextChunkFile.exists()) {
                       // We no longer strictly validate chunk size because Telegram can return smaller chunks at volume boundaries.
                       // Out-of-order chunks are flushed fully during write, and if corrupt due to a rare crash, a pause/resume clears them.
                       final chunkData = await nextChunkFile.readAsBytes();
                       await raf.writeFrom(chunkData);
                       expectedOffset += chunkData.length;
                       try { await nextChunkFile.delete(); } catch(_) {}
                    } else {
                       break;
                    }
                 }
                 
                 part.downloadedBytes = expectedOffset;
                 item.downloadedBytes = item.aggregateDownloadedBytes;
                 
                 if (part.downloadedBytes % (1024 * 1024) < data.length) {
                    await _persist();
                    notifyListeners();
                 }
             } finally {
                 isWriting = false;
                 if (jsCompleted && !completer.isCompleted) {
                     if (expectedOffset >= part.sizeBytes) {
                         completer.complete(true);
                     } else {
                         completer.completeError(Exception("Download completed prematurely. Expected ${part.sizeBytes}, got $expectedOffset"));
                     }
                 }
             }
          } else if (offset > expectedOffset) {
             // Out of order chunk, store it temporarily
             final chunkFile = File('${partFile.path}.chunk_$offset');
             await chunkFile.writeAsBytes(data);
          }
        } else if (msg['type'] == 'parallelChunkError') {
          if (!completer.isCompleted) {
             completer.completeError(Exception(msg['error']));
          }
        } else if (msg['type'] == 'workerCountReduced') {
          final newCount = msg['newCount'] as int;
          if (newCount < item.currentWorkerCount) {
            item.currentWorkerCount = newCount;
            await _persist();
          }
        } else if (msg['type'] == 'parallelDownloadComplete') {
          jsCompleted = true;
          if (!isWriting && !completer.isCompleted) {
             if (expectedOffset >= part.sizeBytes) {
                 completer.complete(true);
             } else {
                 completer.completeError(Exception("Download completed prematurely. Expected ${part.sizeBytes}, got $expectedOffset"));
             }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Ignored async exception in listen handler (likely post-completion chunk): $e');
      }
    });

    try {
      await TelegramClientService().startParallelDownload(
        mediaId: tokenKey,
        fileData: {
          'id': fileLoc['id'] is int ? fileLoc['id'].toString() : fileLoc['id'],
          'accessHash': fileLoc['accessHash'],
          'fileReference': fileLoc['fileReference'],
          'dcId': fileLoc['dcId'],
        },
        totalSize: part.sizeBytes,
        startOffset: part.downloadedBytes,
        workers: workers,
      );

      final result = await completer.future;

      if (result == true) {
        // Fix up contiguous prefix to match exact size on success
        part.downloadedBytes = part.sizeBytes;
        part.status = DownloadPartStatus.completed;
        item.downloadedBytes = item.aggregateDownloadedBytes;
        debugPrint('✅ Part ${part.partIndex} complete: ${DownloadItem.formatBytes(part.sizeBytes)}');
      } else {
        debugPrint('⏸️ Part ${part.partIndex} download cancelled');
        TelegramClientService().cancelParallelDownload(tokenKey);
      }
      
      LocalLoopbackServer().activeStreamCount.removeListener(onActiveStreamsChanged);
      _cancelTokens.remove(tokenKey);
      await raf.close();
      if (sub != null) await sub.cancel();
      await _persist();
      notifyListeners();
      return result;
    } catch (e) {
      LocalLoopbackServer().activeStreamCount.removeListener(onActiveStreamsChanged);
      _cancelTokens.remove(tokenKey);
      TelegramClientService().cancelParallelDownload(tokenKey);
      await raf.close();
      if (sub != null) await sub.cancel();
      debugPrint('❌ Part ${part.partIndex} failed: $e');
      
      if (e is FileSystemException && e.osError?.errorCode == 28) {
        debugPrint('🧹 No space left on device. Cleaning up partial file...');
        try {
          if (await partFile.exists()) await partFile.delete();
        } catch (_) {}
        part.downloadedBytes = 0;
      }
      
      part.status = DownloadPartStatus.failed;
      await _persist();
      notifyListeners();
      return false;
    }
  }

  // ─── Offline Assets & Metadata Fetching ──────────────────

  Future<void> _fetchOfflineAssets(DownloadItem item) async {
    try {
      final assetsDir = Directory('$_storageDir/downloads/assets/${item.mediaId}');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      // 1. Fetch File Info (Track Info / Media Info)
      try {
        final infoRes = await _dio.get('${AppConfig.v1BaseUrl}/api/stream/${item.mediaId}/tracks');
        if (infoRes.data != null) {
          item.mediaInfo = infoRes.data as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('⚠️ DownloadManager: Failed to fetch track info for ${item.mediaId}: $e');
      }

      // 2. Fetch Images (Poster & Backdrop)
      try {
        if (item.posterUrl != null) {
          final posterExt = item.posterUrl!.split('.').last.split('?').first;
          final posterPath = '${assetsDir.path}/poster.$posterExt';
          await _dio.download(item.posterUrl!, posterPath);
          item.localPosterPath = posterPath;
        }
        if (item.backdropUrl != null) {
          final backdropExt = item.backdropUrl!.split('.').last.split('?').first;
          final backdropPath = '${assetsDir.path}/backdrop.$backdropExt';
          await _dio.download(item.backdropUrl!, backdropPath);
          item.localBackdropPath = backdropPath;
        }
        if (item.stillUrl != null) {
          final stillExt = item.stillUrl!.split('.').last.split('?').first;
          final stillPath = '${assetsDir.path}/still.$stillExt';
          await _dio.download(item.stillUrl!, stillPath);
          item.localStillPath = stillPath;
        }
      } catch (e) {
        debugPrint('⚠️ DownloadManager: Failed to download images for ${item.mediaId}: $e');
      }

      // 3. Fetch External Subtitles
      try {
        final subsRes = await _dio.get('${AppConfig.v1BaseUrl}/api/subtitles/movie/${item.mediaId}');
        if (subsRes.data != null && subsRes.data is List) {
          final subsList = subsRes.data as List;
          final savedSubs = <Map<String, dynamic>>[];
          
          for (final sub in subsList) {
            final subId = sub['id'];
            if (subId != null) {
              final subPath = '${assetsDir.path}/$subId.vtt';
              try {
                // Download the subtitle file content
                await _dio.download('${AppConfig.v1BaseUrl}/api/subtitles/file/$subId', subPath);
                
                // Add local path to the subtitle metadata
                final subMeta = Map<String, dynamic>.from(sub);
                subMeta['localPath'] = subPath;
                savedSubs.add(subMeta);
              } catch (e) {
                debugPrint('⚠️ DownloadManager: Failed to download subtitle $subId: $e');
              }
            }
          }
          item.externalSubtitles = savedSubs;
        }
      } catch (e) {
        debugPrint('⚠️ DownloadManager: Failed to fetch external subtitles list for ${item.mediaId}: $e');
      }

    } catch (e) {
      debugPrint('⚠️ DownloadManager: Critical error fetching offline assets for ${item.mediaId}: $e');
    }
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

  // ─── Phase A: Heartbeat Diagnostics ───────────────────────

  void _startDartHeartbeat() {
    if (_dartHeartbeatTimer != null) return;
    _dartHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      debugPrint('DART_HEARTBEAT t=${DateTime.now().millisecondsSinceEpoch} active=$_activeDownloads');
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        DownloadServiceChannel.resumeWebviewTimers();
        TelegramClientService().pingWebview();
      }
    });
  }

  void _stopDartHeartbeat() {
    _dartHeartbeatTimer?.cancel();
    _dartHeartbeatTimer = null;
  }
}

// ─── Riverpod Provider ─────────────────────────────────────

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager();
});
