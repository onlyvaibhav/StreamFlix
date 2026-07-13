import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/config/app_config.dart';
import 'package:streamflix/core/network/api_endpoints.dart';
import 'package:streamflix/core/network/dio_client.dart';
import 'package:streamflix/features/player/data/models/stream_track.dart';
import 'package:streamflix/features/player/data/models/external_subtitle.dart';

import 'package:streamflix/features/player/data/models/file_info.dart';

/// Remote data source for streaming, track probing, subtitles, and heartbeat
class StreamRemoteDataSource {
  final Dio _dio;

  StreamRemoteDataSource(this._dio);

  /// Probe track info (audio tracks, subtitle tracks, duration)
  /// GET /api/stream/:id/tracks
  Future<TrackInfo> getTrackInfo(String fileId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.streamTracks.replaceAll(':id', fileId),
      );
      if (response.data is Map<String, dynamic>) {
        return TrackInfo.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Unexpected response format for track info');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get multipart movie part details
  /// GET /api/stream/:id/part-info
  Future<Map<String, dynamic>> getPartInfo(String fileId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.streamPartInfo.replaceAll(':id', fileId),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('⚠️ Part-info fetch failed: $e');
      return {};
    }
  }

  /// Get file metadata including GramJS authentication details
  /// GET /api/stream/:id/file-info
  Future<FileInfo?> getFileInfo(String fileId) async {
    try {
      final response = await _dio.get(
        '${AppConfig.v1BaseUrl}/api/stream/$fileId/file-info',
      );
      if (response.data is Map<String, dynamic>) {
        return FileInfo.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('⚠️ File Info fetch failed: ${e.message}');
      return null;
    }
  }

  /// Search external subtitles for a movie
  /// GET /api/subtitles/movie/:movieId
  Future<List<ExternalSubtitle>> getExternalSubtitles(String movieId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.externalSubtitlesList.replaceAll(':movieId', movieId),
      );
      if (response.data is Map<String, dynamic>) {
        final subtitles = response.data['subtitles'];
        if (subtitles is List) {
          return subtitles
              .map((json) => ExternalSubtitle.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      debugPrint('⚠️ External subtitles fetch failed: ${e.message}');
      return []; // Non-fatal — subtitles are optional
    }
  }

  /// Send heartbeat ping to keep backend session alive
  /// GET /api/stream/:id/heartbeat (fire-and-forget)
  Future<void> sendHeartbeat(String fileId) async {
    try {
      await _dio.get(
        ApiEndpoints.streamHeartbeat.replaceAll(':id', fileId),
      );
    } catch (_) {
      // Heartbeat failures are non-fatal
    }
  }

  // ==================== URL Builders ====================

  /// Build the stream URL for direct or remux mode
  /// Direct: /api/stream/:id (with Range headers handled by player)
  /// Remux:  /api/stream/:id?audioTrack=X&start=Y
  static String buildStreamUrl(
    String fileId, {
    int? audioTrack,
    double? startSeconds,
  }) {
    final base = '${AppConfig.v1BaseUrl}/api/stream/$fileId';
    final params = <String, String>{};

    if (audioTrack != null) {
      params['audioTrack'] = audioTrack.toString();
    }
    if (startSeconds != null && startSeconds > 0) {
      params['start'] = startSeconds.toStringAsFixed(1);
    }

    if (params.isEmpty) return base;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$base?$query';
  }

  /// Build URL for extracting an embedded subtitle track as WebVTT
  static String buildEmbeddedSubtitleUrl(String fileId, int streamIndex) {
    return '${AppConfig.v1BaseUrl}/api/stream/$fileId/subtitle/$streamIndex';
  }

  /// Build URL for downloading an external subtitle file
  static String buildExternalSubtitleUrl(String subtitleId) {
    return '${AppConfig.v1BaseUrl}/api/subtitles/file/$subtitleId';
  }

  // ==================== WATCH PROGRESS ====================

  /// Save watch progress to the backend
  Future<void> saveWatchProgress({
    required String fileId,
    required int positionSeconds,
    required int durationSeconds,
    String? title,
    String? posterPath,
    String? mediaType,
    int? season,
    int? episode,
    String? showId,
  }) async {
    try {
      await _dio.post(
        '${AppConfig.v1BaseUrl}/api/progress',
        data: {
          'fileId': fileId,
          'positionSeconds': positionSeconds,
          'durationSeconds': durationSeconds,
          'title': title,
          'posterPath': posterPath,
          'mediaType': mediaType,
          'season': season,
          'episode': episode,
          'showId': showId,
        },
      );
    } catch (e) {
      debugPrint('⚠️ Save watch progress failed: $e');
    }
  }

  /// Get watch progress from the backend
  Future<List<Map<String, dynamic>>> getWatchProgress() async {
    try {
      final response = await _dio.get('${AppConfig.v1BaseUrl}/api/progress');
      if (response.data is Map<String, dynamic> && response.data['success'] == true) {
        final progress = response.data['progress'];
        if (progress is List) {
          return List<Map<String, dynamic>>.from(progress);
        }
      }
      return [];
    } catch (e) {
      debugPrint('⚠️ Get watch progress failed: $e');
      return [];
    }
  }

  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('Connection timeout. Check your network.');
      case DioExceptionType.receiveTimeout:
        return Exception('Server took too long to respond.');
      case DioExceptionType.badResponse:
        return Exception('Server error: ${e.response?.statusCode}');
      default:
        return Exception('Network error: ${e.message}');
    }
  }
}

/// Provider for StreamRemoteDataSource
final streamRemoteDataSourceProvider = Provider<StreamRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return StreamRemoteDataSource(dio);
});
