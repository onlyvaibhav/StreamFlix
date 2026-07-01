import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WatchHistoryItem {
  final String movieId; // TMDB ID (or show_tmdbId)
  final String? episodeId; // Playable file ID
  final String title; // Episode or Movie title
  final String? poster;
  final String? backdrop;
  final int position; // seconds
  final int duration; // seconds
  final DateTime updatedAt;
  final String? tvShowName;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeTitle;

  WatchHistoryItem({
    required this.movieId,
    this.episodeId,
    required this.title,
    this.poster,
    this.backdrop,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.tvShowName,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
  });

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'episodeId': episodeId,
    'title': title,
    'poster': poster,
    'backdrop': backdrop,
    'position': position,
    'duration': duration,
    'updatedAt': updatedAt.toIso8601String(),
    'tvShowName': tvShowName,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'episodeTitle': episodeTitle,
  };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) => WatchHistoryItem(
    movieId: json['movieId'] as String,
    episodeId: json['episodeId'] as String?,
    title: json['title'] as String,
    poster: json['poster'] as String?,
    backdrop: json['backdrop'] as String?,
    position: json['position'] as int,
    duration: json['duration'] as int,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    tvShowName: json['tvShowName'] as String?,
    seasonNumber: json['seasonNumber'] as int?,
    episodeNumber: json['episodeNumber'] as int?,
    episodeTitle: json['episodeTitle'] as String?,
  );
}

class WatchHistoryManager {
  static final _items = <String, WatchHistoryItem>{};
  static bool _loaded = false;
  
  static File _getFile() {
    final tempDir = Directory.systemTemp;
    return File('${tempDir.path}/streamflix_history.json');
  }

  static Future<void> loadHistory() async {
    if (_loaded) return;
    try {
      final file = _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _items.clear();
        for (final json in list) {
          final item = WatchHistoryItem.fromJson(json as Map<String, dynamic>);
          _items[item.movieId] = item;
        }
      }
      _loaded = true;
    } catch (e) {
      debugPrint('⚠️ Failed to load watch history: $e');
    }
  }

  static Future<void> saveProgress({
    required String movieId,
    String? episodeId,
    required String title,
    String? poster,
    String? backdrop,
    required int position,
    required int duration,
    String? tvShowName,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
  }) async {
    // Skip if duration is invalid or progress is less than 2s
    if (duration <= 0 || position < 2) return;
    
    // If completed (>95% watched), remove it
    if (position >= duration * 0.95) {
      _items.remove(movieId);
    } else {
      _items[movieId] = WatchHistoryItem(
        movieId: movieId,
        episodeId: episodeId,
        title: title,
        poster: poster,
        backdrop: backdrop,
        position: position,
        duration: duration,
        updatedAt: DateTime.now(),
        tvShowName: tvShowName,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
      );
    }
    
    await _persist();
  }

  static WatchHistoryItem? getProgress(String movieId) {
    return _items[movieId];
  }

  static List<WatchHistoryItem> getContinueWatchingList() {
    final sorted = _items.values.toList();
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  static Future<void> _persist() async {
    try {
      final file = _getFile();
      final list = _items.values.map((i) => i.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('⚠️ Failed to save watch history: $e');
    }
  }
}
