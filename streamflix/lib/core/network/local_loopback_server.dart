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

          // Attempt to fetch the chunk, with one retry on FILE_REFERENCE_EXPIRED
          for (int attempt = 0; attempt < 2; attempt++) {
            try {
              // Always read from the (potentially refreshed) _registeredFiles map
              final currentFileInfo = _registeredFiles[fileId]!;
              bytes = await TelegramClientService().fetchChunk(
                documentId: currentFileInfo['documentId'],
                accessHash: currentFileInfo['accessHash'],
                fileReference: currentFileInfo['fileReference'],
                offset: currentOffset,
                limit: chunkSize,
              );
              break; // Success — exit retry loop
            } catch (e) {
              final errorStr = e.toString().toUpperCase();
              if (attempt == 0 && (errorStr.contains('FILE_REFERENCE_EXPIRED') || errorStr.contains('FILE_REFERENCE'))) {
                debugPrint('🔄 FILE_REFERENCE_EXPIRED at offset $currentOffset, refreshing...');
                
                final channelId = _registeredFiles[fileId]?['channelId'];
                if (channelId != null) {
                  try {
                    final refreshedData = await TelegramClientService().refreshFileReference(channelId, fileId);
                    _registeredFiles[fileId]!['fileReference'] = refreshedData['fileReference'];
                    if (refreshedData['accessHash'] != null) {
                        _registeredFiles[fileId]!['accessHash'] = refreshedData['accessHash'];
                    }
                    if (refreshedData['id'] != null) {
                        _registeredFiles[fileId]!['documentId'] = int.parse(refreshedData['id']);
                    }
                    retried = true;
                    debugPrint('✅ File reference refreshed successfully from Telegram client.');
                    continue; // Retry with fresh reference
                  } catch (refErr) {
                    debugPrint('❌ Failed to refresh file reference: $refErr');
                  }
                } else {
                  debugPrint('❌ Cannot refresh file reference because channelId is missing.');
                }
              }
              debugPrint('❌ Chunk stream interrupted at offset $currentOffset: $e');
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
}
