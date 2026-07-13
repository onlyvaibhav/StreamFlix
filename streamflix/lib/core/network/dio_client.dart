import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:streamflix/core/config/app_config.dart';

/// Cache entry model for ETag validation
class CacheEntry {
  final String etag;
  final dynamic data;
  final DateTime timestamp;

  CacheEntry({
    required this.etag,
    required this.data,
    required this.timestamp,
  });
}

/// Injects custom session token into requests
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final box = Hive.box('authBox');
    final sessionToken = box.get('sessionToken') as String?;
    if (sessionToken != null && sessionToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $sessionToken';
    }
    return handler.next(options);
  }
}

/// Custom ETag Cache Interceptor supporting 304 responses
class ETagCacheInterceptor extends Interceptor {
  final Map<String, CacheEntry> _cache = {};
  final int maxEntries;

  ETagCacheInterceptor({this.maxEntries = 100});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Only cache GET requests
    if (options.method != 'GET') {
      return handler.next(options);
    }

    final cacheKey = _getCacheKey(options);
    final cachedEntry = _cache[cacheKey];

    if (cachedEntry != null) {
      options.headers['If-None-Match'] = cachedEntry.etag;
      debugPrint('📦 ETag Cache [REQUEST]: Found cached entry for ${options.uri}, sending If-None-Match: ${cachedEntry.etag}');
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method != 'GET') {
      return handler.next(response);
    }

    final cacheKey = _getCacheKey(response.requestOptions);
    final etag = response.headers.value('etag');

    if (response.statusCode == 304) {
      final cachedEntry = _cache[cacheKey];
      if (cachedEntry != null) {
        debugPrint('📦 ETag Cache [RESPONSE]: Status 304 (Not Modified) for ${response.requestOptions.uri}. Returning cached data.');
        final cachedResponse = Response(
          requestOptions: response.requestOptions,
          data: cachedEntry.data,
          statusCode: 200,
          headers: response.headers,
        );
        return handler.resolve(cachedResponse);
      }
    }

    if (response.statusCode == 200 && etag != null && response.data != null) {
      debugPrint('📦 ETag Cache [RESPONSE]: Status 200 with ETag: $etag. Caching data.');
      _saveToCache(cacheKey, etag, response.data);
    }

    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.badResponse && err.response?.statusCode == 304) {
      final cacheKey = _getCacheKey(err.requestOptions);
      final cachedEntry = _cache[cacheKey];
      if (cachedEntry != null) {
        debugPrint('📦 ETag Cache [ERROR-RESPONSE]: Status 304 (Not Modified) for ${err.requestOptions.uri}. Resolving with cached data.');
        final cachedResponse = Response(
          requestOptions: err.requestOptions,
          data: cachedEntry.data,
          statusCode: 200,
          headers: err.response!.headers,
        );
        return handler.resolve(cachedResponse);
      }
    }
    return handler.next(err);
  }

  String _getCacheKey(RequestOptions options) {
    return '${options.uri.toString()}?${options.queryParameters.toString()}';
  }

  void _saveToCache(String key, String etag, dynamic data) {
    if (_cache.length >= maxEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = CacheEntry(
      etag: etag,
      data: data,
      timestamp: DateTime.now(),
    );
  }
}

/// Custom Retry Interceptor with exponential backoff on connection failure
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final int baseDelayMs;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;

    final isConnectionError = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;
        
    final innerErrorStr = err.error?.toString().toLowerCase() ?? '';
    final isNoInternet = innerErrorStr.contains('failed host lookup') || 
                         innerErrorStr.contains('network is unreachable') ||
                         innerErrorStr.contains('no route to host');

    int retryCount = requestOptions.extra['retry_count'] ?? 0;

    if (isConnectionError && !isNoInternet && retryCount < maxRetries && requestOptions.method == 'GET') {
      retryCount++;
      requestOptions.extra['retry_count'] = retryCount;

      final delay = baseDelayMs * retryCount;
      debugPrint('🔄 Network Retry Interceptor: Connection failure. Retrying ${requestOptions.uri} in ${delay}ms (Attempt $retryCount/$maxRetries)...');

      await Future.delayed(Duration(milliseconds: delay));

      try {
        final response = await dio.fetch(requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }

    return handler.next(err);
  }
}

/// Dio HTTP client provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.v1BaseUrl,
      connectTimeout: const Duration(seconds: AppConfig.timeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConfig.timeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Register Auth interceptor
  dio.interceptors.add(AuthInterceptor());

  // Register ETag caching interceptor
  final cacheInterceptor = ETagCacheInterceptor();
  dio.interceptors.add(cacheInterceptor);

  // Register Retry interceptor
  dio.interceptors.add(RetryInterceptor(dio: dio));

  // Request & Response logger
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('🌐 REQUEST[${options.method}] => ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('❌ ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}');
        debugPrint('   Message: ${error.message}');
        return handler.next(error);
      },
    ),
  );

  return dio;
});
