import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:streamflix/core/network/telegram_client_service.dart';

/// Callback type for refreshing file info when a file reference expires.
/// Returns a map with keys: documentId, accessHash, fileReference, size
typedef FileInfoRefresher = Future<Map<String, dynamic>?> Function(String fileId);

class LocalLoopbackServer {
  static final LocalLoopbackServer _instance = LocalLoopbackServer._internal();
  factory LocalLoopbackServer() => _instance;
  LocalLoopbackServer._internal();

  HttpServer? _server;
  int get port => _server?.port ?? 8080;

  // Store pre-registered parts for multipart handling
  // Map of fileId -> { documentId, accessHash, fileReference, size }
  final Map<String, Map<String, dynamic>> _registeredFiles = {};

  final Set<String> activeStreams = {};
  final ValueNotifier<int> activeStreamCount = ValueNotifier(0);


  /// Optional callback to refresh file info when FILE_REFERENCE_EXPIRED occurs
  FileInfoRefresher? _fileInfoRefresher;

  void setFileInfoRefresher(FileInfoRefresher refresher) {
    _fileInfoRefresher = refresher;
  }

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
  }) {
    _registeredFiles[fileId] = {
      'documentId': documentId,
      'accessHash': accessHash,
      'fileReference': fileReference,
      'size': size,
      'channelId': channelId,
    };
    debugPrint('📦 Registered part $fileId in loopback server (size: $size, channelId: $channelId)');
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

  /// Refresh the file reference for a given fileId by calling the backend
  Future<bool> _refreshFileReference(String fileId) async {
    if (_fileInfoRefresher == null) {
      debugPrint('⚠️ No file info refresher registered, cannot refresh file reference');
      return false;
    }

    try {
      debugPrint('🔄 Refreshing file reference for $fileId...');
      final freshInfo = await _fileInfoRefresher!(fileId);
      if (freshInfo != null) {
        _registeredFiles[fileId] = freshInfo;
        debugPrint('✅ File reference refreshed for $fileId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh file reference: $e');
    }
    return false;
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
          bool retried = false;

          // Attempt to fetch the chunk from the read-ahead manager, with up to 3 retries (4 attempts total)
          for (int attempt = 0; attempt < 4; attempt++) {
            try {
              final manager = _getOrCreateManager(fileId!);
              bytes = await manager.getChunk(currentOffset);
              break; // Success — exit retry loop
            } catch (e) {
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
        final errorStr = e.toString().toUpperCase();
        if (errorStr.contains('FILE_REFERENCE_EXPIRED') || errorStr.contains('FILE_REFERENCE')) {
             await server.refreshFileReferenceForFile(fileId);
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
