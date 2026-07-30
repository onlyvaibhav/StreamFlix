import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:streamflix/core/network/telegram_client_service.dart';

class LocalLoopbackServer {
  static final LocalLoopbackServer _instance = LocalLoopbackServer._internal();
  factory LocalLoopbackServer() => _instance;
  LocalLoopbackServer._internal();

  HttpServer? _server;
  int get port => _server?.port ?? 8080;

  // Store pre-registered parts for multipart handling
  // Map of fileId -> { documentId, accessHash, fileReference, size, channelId, messageId }
  final Map<String, Map<String, dynamic>> _registeredFiles = {};

  final Set<String> activeStreams = {};
  final ValueNotifier<int> activeStreamCount = ValueNotifier(0);

  /// De-duplication lock for concurrent refresh calls per fileId
  final Map<String, Completer<bool>> _pendingRefreshes = {};

  Future<void> start() async {
    if (_server != null) return;
    
    final handler = Pipeline().addHandler(_handleRequest);
    
    // Bind to localhost on a random available port
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    debugPrint('🚀 Local Loopback Server listening on http://127.0.0.1:${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  void registerFile({
    required String fileId,
    required int documentId,
    required String accessHash,
    required List<int> fileReference,
    required int size,
    String? channelId,
    String? messageId,
  }) {
    _registeredFiles[fileId] = {
      'documentId': documentId,
      'accessHash': accessHash,
      'fileReference': fileReference,
      'size': size,
      'channelId': channelId,
      'messageId': messageId,
    };
    debugPrint('📦 Registered part $fileId in loopback server (size: $size, channelId: $channelId, messageId: $messageId)');
  }

  void clearRegisteredFiles() {
    for (var manager in _readAheadManagers.values) {
      manager.stop();
    }
    _readAheadManagers.clear();
    _registeredFiles.clear();
  }

  bool isRegistered(String fileId) {
    return _registeredFiles.containsKey(fileId);
  }

  /// Stop and remove a specific ReadAheadManager (e.g. when playback gives up)
  void stopManager(String fileId) {
    final manager = _readAheadManagers.remove(fileId);
    if (manager != null) {
      manager.stop();
      debugPrint('🛑 Stopped ReadAheadManager for $fileId');
    }
  }

  /// Refresh the file reference for a given fileId using the DEVICE's own GramJS session.
  /// This is critical: file references are session-scoped, so we must refresh using
  /// the same Telegram session that will call upload.GetFile.
  Future<bool> _refreshFileReference(String fileId) async {
    // De-duplicate: if a refresh is already in flight for this fileId, wait for it
    if (_pendingRefreshes.containsKey(fileId)) {
      debugPrint('⏳ Refresh already in flight for $fileId, waiting...');
      return _pendingRefreshes[fileId]!.future;
    }

    final completer = Completer<bool>();
    _pendingRefreshes[fileId] = completer;

    try {
      final fileInfo = _registeredFiles[fileId];
      if (fileInfo == null) {
        debugPrint('⚠️ Cannot refresh: no registered file info for $fileId');
        completer.complete(false);
        return false;
      }

      final channelId = fileInfo['channelId']?.toString();
      final messageId = fileInfo['messageId']?.toString() ?? fileId;

      if (channelId == null) {
        debugPrint('⚠️ Cannot refresh file reference for $fileId: missing channelId');
        completer.complete(false);
        return false;
      }

      debugPrint('🔄 Refreshing file reference for $fileId via device GramJS (channelId: $channelId, messageId: $messageId)...');
      
      final refreshed = await TelegramClientService().refreshFileReference(channelId, messageId);
      
      // refreshed contains: { fileReference: List<int>, accessHash: String, id: int/String }
      final newRef = refreshed['fileReference'];
      if (newRef != null) {
        // Update the registered file with the fresh reference from this device's session
        fileInfo['fileReference'] = newRef is List<int> ? newRef : (newRef as Uint8List).toList();
        if (refreshed['accessHash'] != null) {
          fileInfo['accessHash'] = refreshed['accessHash'].toString();
        }
        final refHash = base64Encode((fileInfo['fileReference'] as List<int>).take(8).toList());
        debugPrint('✅ File reference refreshed for $fileId (ref prefix: $refHash)');
        completer.complete(true);
        return true;
      } else {
        debugPrint('❌ Refresh returned null fileReference for $fileId');
        completer.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh file reference via GramJS: $e');
      completer.complete(false);
      return false;
    } finally {
      _pendingRefreshes.remove(fileId);
    }
  }

  Future<Response> _handleRequest(Request request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      return Response(405, body: 'Method Not Allowed');
    }

    final pathSegments = request.url.pathSegments;
    // Expected path: /stream/<fileId>
    if (pathSegments.isEmpty || pathSegments.first != 'stream') {
      return Response.notFound('Not Found');
    }

    final fileId = pathSegments.length > 1 ? pathSegments[1] : null;
    if (fileId == null || !_registeredFiles.containsKey(fileId)) {
      return Response.notFound('File Not Registered');
    }

    final fileInfo = _registeredFiles[fileId]!;
    final int fileSize = fileInfo['size'];

    if (request.method == 'HEAD') {
      return Response.ok(null, headers: {
        'Content-Type': 'video/mp4',
        'Accept-Ranges': 'bytes',
        'Content-Length': fileSize.toString(),
        'Access-Control-Allow-Origin': '*',
      });
    }

    // Handle Range requests
    final rangeHeader = request.headers['range'];
    int start = 0;
    int end = fileSize - 1;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final range = rangeHeader.substring(6).split('-');
      if (range.isNotEmpty && range[0].isNotEmpty) {
        start = int.parse(range[0]);
      }
      if (range.length > 1 && range[1].isNotEmpty) {
        end = int.parse(range[1]);
      }
    }

    if (start >= fileSize) {
      return Response(
        416,
        headers: {
          'Content-Range': 'bytes */$fileSize',
          'Accept-Ranges': 'bytes',
        },
      );
    }

    final int length = end - start + 1;
    
    // Calculate aligned offsets (1MB / 512KB boundaries) - Telegram requires this
    final int chunkSize = 524288; // 512 KB alignment
    final int alignedStart = (start ~/ chunkSize) * chunkSize;
    final int alignedLimit = ((end ~/ chunkSize) + 1) * chunkSize;
    
    final fetchLimit = alignedLimit - alignedStart;

    debugPrint('📡 Range request: $start-$end (aligned: $alignedStart, limit: $fetchLimit)');

    try {
      Stream<List<int>> byteStream() async* {
        int currentOffset = alignedStart;
        int bytesRemaining = length;
        int firstChunkSliceStart = start - alignedStart;

        while (bytesRemaining > 0) {
          Uint8List? bytes;

          // Attempt to fetch the chunk from the read-ahead manager, with up to 3 retries (4 attempts total)
          for (int attempt = 0; attempt < 4; attempt++) {
            try {
              final manager = _getOrCreateManager(fileId);
              bytes = await manager.getChunk(currentOffset);
              break; // Success — exit retry loop
            } catch (e) {
              if (e.toString().contains("ReadAheadManager stopped")) {
                return;
              }
              if (e.toString().contains("Seek aborted fetch")) {
                debugPrint('🔄 Chunk stream seek aborted fetch, retrying immediately');
                continue; // Immediate retry if aborted due to a seek race condition
              }
              if (attempt < 3) {
                 debugPrint('🔄 Chunk stream error at offset $currentOffset, retrying in 1s (Attempt ${attempt + 1}/3): $e');
                 await Future.delayed(const Duration(seconds: 1));
                 continue;
              }
              
              debugPrint('❌ Chunk stream interrupted at offset $currentOffset after 4 attempts: $e');
              return; // Give up
            }
          }

          if (bytes == null || bytes.isEmpty) {
            break; // EOF
          }

          int sliceStart = 0;
          if (currentOffset == alignedStart) {
            sliceStart = firstChunkSliceStart;
          }

          List<int> chunkToYield = bytes.sublist(sliceStart);
          if (chunkToYield.length > bytesRemaining) {
            chunkToYield = chunkToYield.sublist(0, bytesRemaining);
          }

          yield chunkToYield;

          bytesRemaining -= chunkToYield.length;
          currentOffset += chunkSize;
        }
      }

      final headers = {
        'Content-Type': 'video/mp4', // Assuming mp4/mkv, media_kit will probe it
        'Accept-Ranges': 'bytes',
        'Content-Length': length.toString(),
        'Content-Range': 'bytes $start-$end/$fileSize',
        'Access-Control-Allow-Origin': '*',
      };

      // Wrap byteStream to track active streams
      final trackingStream = byteStream().map((chunk) => chunk).handleError((error) {
        throw error;
      });
      
      final controller = StreamController<List<int>>();
      final streamId = DateTime.now().millisecondsSinceEpoch.toString();
      
      controller.onListen = () {
        activeStreams.add(streamId);
        activeStreamCount.value = activeStreams.length;
        trackingStream.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            activeStreams.remove(streamId);
            activeStreamCount.value = activeStreams.length;
            controller.close();
          },
          cancelOnError: true,
        );
      };
      
      controller.onCancel = () {
        activeStreams.remove(streamId);
        activeStreamCount.value = activeStreams.length;
      };

      return Response(
        206, // Partial Content
        body: controller.stream,
        headers: headers,
      );
    } catch (e) {
      debugPrint('❌ Failed to setup chunk stream: $e');
      return Response.internalServerError(body: 'Internal Server Error: $e');
    }
  }
  Map<String, dynamic>? getRegisteredFile(String fileId) => _registeredFiles[fileId];

  Future<bool> refreshFileReferenceForFile(String fileId) => _refreshFileReference(fileId);

  final Map<String, _ReadAheadManager> _readAheadManagers = {};

  _ReadAheadManager _getOrCreateManager(String fileId) {
    if (!_readAheadManagers.containsKey(fileId)) {
      _readAheadManagers[fileId] = _ReadAheadManager(fileId, this);
    }
    return _readAheadManagers[fileId]!;
  }


}

class _ReadAheadManager {
  final String fileId;
  final LocalLoopbackServer server;
  final int chunkSize = 524288;
  final int maxReadAheadChunks = 20;

  final Map<int, Uint8List> _cache = {};
  final Map<int, Completer<Uint8List>> _waiters = {};
  
  int _targetOffset = -1;
  bool _isFetching = false;
  bool _isStopped = false;

  _ReadAheadManager(this.fileId, this.server);

  void startOrUpdateTarget(int offset) {
    if (_isStopped) return;
    
    if (_targetOffset != -1 && (offset - _targetOffset).abs() > chunkSize * maxReadAheadChunks) {
      _cache.clear();
      for (var completer in _waiters.values) {
        if (!completer.isCompleted) {
          completer.completeError(Exception("Seek aborted fetch"));
        }
      }
      _waiters.clear();
    }
    
    _targetOffset = offset;
    
    if (!_isFetching) {
      _startFetchLoop();
    }
  }

  Future<void> _startFetchLoop() async {
    _isFetching = true;
    while (!_isStopped && _targetOffset != -1) {
      int offsetToFetch = -1;
      final fileInfo = server.getRegisteredFile(fileId);
      if (fileInfo == null) break;
      final int fileSize = fileInfo['size'];

      for (int i = 0; i < maxReadAheadChunks; i++) {
        int checkOffset = _targetOffset + (i * chunkSize);
        if (checkOffset >= fileSize) break;
        
        if (!_cache.containsKey(checkOffset)) {
          offsetToFetch = checkOffset;
          break;
        }
      }

      if (offsetToFetch == -1) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }
      
      try {
        await Future.delayed(const Duration(milliseconds: 40)); 
        
        if (_isStopped) break; // Check before fetching
        
        final currentFileInfo = server.getRegisteredFile(fileId);
        if (currentFileInfo == null) break;

        final bytes = await TelegramClientService().fetchChunk(
          documentId: currentFileInfo['documentId'],
          accessHash: currentFileInfo['accessHash'],
          fileReference: currentFileInfo['fileReference'],
          offset: offsetToFetch,
          limit: chunkSize,
        );
        
        _cache[offsetToFetch] = bytes;
        
        if (_waiters.containsKey(offsetToFetch)) {
          _waiters[offsetToFetch]!.complete(bytes);
          _waiters.remove(offsetToFetch);
        }
        
        _cache.removeWhere((k, v) => k < _targetOffset - (chunkSize * 2));
      } catch (e) {
        if (_isStopped) break; // Don't refresh if we've been stopped
        
        final errorStr = e.toString().toUpperCase();
        debugPrint('⚠️ Chunk fetch caught error: $e');
        
        if (errorStr.contains('FILE_REFERENCE_EXPIRED') || errorStr.contains('FILE_REFERENCE')) {
             bool refreshed = await server.refreshFileReferenceForFile(fileId);
             if (_isStopped) break; // Check after async refresh
             if (!refreshed) {
                 debugPrint('❌ File reference refresh failed. Backing off for 2 seconds.');
                 await Future.delayed(const Duration(seconds: 2));
             }
        } else {
             await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    _isFetching = false;
  }

  Future<Uint8List> getChunk(int offset) async {
    startOrUpdateTarget(offset);
    
    if (_cache.containsKey(offset)) {
      return _cache[offset]!;
    }
    
    if (!_waiters.containsKey(offset)) {
      _waiters[offset] = Completer<Uint8List>();
    }
    
    return _waiters[offset]!.future;
  }

  void stop() {
    _isStopped = true;
    _cache.clear();
    for (var completer in _waiters.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception("ReadAheadManager stopped"));
      }
    }
    _waiters.clear();
  }
}
