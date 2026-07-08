import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
  // Map of fileId -> { documentId, accessHash, fileReference, size }
  final Map<String, Map<String, dynamic>> _registeredFiles = {};

  Future<void> start() async {
    if (_server != null) return;
    
    final handler = Pipeline().addHandler(_handleRequest);
    
    // Bind to localhost on a random available port
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    debugPrint('🚀 Local Loopback Server listening on http://localhost:${_server!.port}');
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
  }) {
    _registeredFiles[fileId] = {
      'documentId': documentId,
      'accessHash': accessHash,
      'fileReference': fileReference,
      'size': size,
    };
    debugPrint('📦 Registered part $fileId in loopback server (size: $size)');
  }

  void clearRegisteredFiles() {
    _registeredFiles.clear();
  }

  Future<Response> _handleRequest(Request request) async {
    if (request.method != 'GET') {
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
      final bytes = await TelegramClientService().fetchChunk(
        documentId: fileInfo['documentId'],
        accessHash: fileInfo['accessHash'],
        fileReference: fileInfo['fileReference'],
        offset: alignedStart,
        limit: fetchLimit,
      );

      // Slice the returned aligned bytes to exactly match the requested range
      final int sliceStart = start - alignedStart;
      final int sliceEnd = sliceStart + length;
      
      final Uint8List responseBytes = bytes.sublist(
        sliceStart,
        sliceEnd > bytes.length ? bytes.length : sliceEnd,
      );

      final headers = {
        'Content-Type': 'video/mp4', // Assuming mp4/mkv, media_kit will probe it
        'Accept-Ranges': 'bytes',
        'Content-Length': responseBytes.length.toString(),
        'Content-Range': 'bytes $start-${start + responseBytes.length - 1}/$fileSize',
        'Access-Control-Allow-Origin': '*',
      };

      return Response(
        206, // Partial Content
        body: Stream.value(responseBytes),
        headers: headers,
      );
    } catch (e) {
      debugPrint('❌ Failed to fetch chunk from Telegram: $e');
      return Response.internalServerError(body: 'Telegram API Error: $e');
    }
  }
}
