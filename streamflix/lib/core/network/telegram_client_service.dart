import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TelegramClientService {
  static final TelegramClientService _instance = TelegramClientService._internal();
  factory TelegramClientService() => _instance;
  TelegramClientService._internal();

  late final WebViewController _controller;
  
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get isReady => _readyCompleter.future;

  // Track chunk requests
  int _requestIdCounter = 0;
  final Map<int, Completer<Uint8List>> _pendingChunkRequests = {};

  // Track auth state
  final StreamController<String> _authStream = StreamController<String>.broadcast();
  Stream<String> get authStateStream => _authStream.stream;

  String? _sessionString;
  String? _phoneCodeHash;
  Map<String, dynamic>? _userObj;
  String? _lastRawMsg;

  WebViewController get webViewController => _controller;

  Future<void> init({String? initialSession}) async {
    _sessionString = initialSession;
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _handleMessageFromJS,
      );

    if (!kIsWeb) {
      // Load from Flutter assets — this correctly resolves relative <script src="..."> paths
      await _controller.loadFlutterAsset('assets/gramjs/gramjs_worker.html');
    }
  }

  void _handleMessageFromJS(JavaScriptMessage message) {
    try {
      final msg = jsonDecode(message.message) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'webviewLoaded':
          debugPrint('🌐 GramJS Webview Loaded');
          _sendInit();
          break;
        case 'ready':
          debugPrint('✅ GramJS Client Ready');
          _sessionString = msg['session'] as String?;
          if (!_readyCompleter.isCompleted) {
            _readyCompleter.complete();
          }
          _authStream.add('ready');
          break;
        case 'phoneCodeSent':
          _phoneCodeHash = msg['phoneCodeHash'] as String?;
          _authStream.add('phoneCodeSent');
          break;
        case 'signedIn':
          _lastRawMsg = message.message;
          _sessionString = msg['session'] as String?;
          _userObj = msg['user'] != null ? Map<String, dynamic>.from(msg['user'] as Map) : null;
          
          _authStream.add('signedIn');
          break;
        case 'passwordNeeded':
          _authStream.add('passwordNeeded');
          break;
        case 'chunkResult':
          final reqId = msg['requestId'] as int;
          final dataBase64 = msg['data'] as String;
          if (_pendingChunkRequests.containsKey(reqId)) {
            _pendingChunkRequests[reqId]!.complete(base64Decode(dataBase64));
            _pendingChunkRequests.remove(reqId);
          }
          break;
        case 'chunkError':
          final reqId = msg['requestId'] as int;
          final error = msg['error'] as String;
          if (_pendingChunkRequests.containsKey(reqId)) {
            _pendingChunkRequests[reqId]!.completeError(Exception(error));
            _pendingChunkRequests.remove(reqId);
          }
          final upperError = error.toUpperCase();
          if (upperError.contains('AUTH_KEY_UNREGISTERED') || upperError.contains('SESSION_REVOKED') || upperError.contains('USER_DEACTIVATED')) {
            _authStream.add('error:revoked');
          }
          break;
        case 'fileReferenceRefreshed':
          final requestId = int.parse(msg['requestId'].toString());
          if (_pendingFileReferenceRequests.containsKey(requestId)) {
            _pendingFileReferenceRequests[requestId]!.complete({
              'fileReference': base64Decode(msg['data']),
              'accessHash': msg['accessHash'],
              'id': msg['id'],
            });
            _pendingFileReferenceRequests.remove(requestId);
          }
          break;
        case 'fileReferenceError':
          final requestId = int.parse(msg['requestId'].toString());
          if (_pendingFileReferenceRequests.containsKey(requestId)) {
            _pendingFileReferenceRequests[requestId]!.completeError(Exception(msg['error']));
            _pendingFileReferenceRequests.remove(requestId);
          }
          break;
        case 'error':
          debugPrint('❌ GramJS Error: ${msg['error']}');
          _authStream.add('error:${msg['error']}');
          break;
        case 'log':
          debugPrint('📄 JS Log: ${msg['message']}');
          break;
        default:
          debugPrint('⚠️ Unknown message from JS: $type');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to parse message from JS: $e');
    }
  }

  final Map<int, Completer<Map<String, dynamic>>> _pendingFileReferenceRequests = {};

  Future<Map<String, dynamic>> refreshFileReference(String channelId, String messageId) async {
    await isReady;
    final reqId = _requestIdCounter++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingFileReferenceRequests[reqId] = completer;

    _sendToJS({
      'type': 'refreshFileReference',
      'requestId': reqId,
      'channelId': channelId,
      'messageId': messageId,
    });

    return completer.future;
  }

  void _sendInit() {
    final apiId = int.tryParse(dotenv.env['TELEGRAM_API_ID'] ?? '') ?? 25193240;
    final apiHash = dotenv.env['TELEGRAM_API_HASH'] ?? '24079455e34ad7368838fef9798878e7';
    final initMsg = {
      'type': 'init',
      'session': _sessionString ?? '',
      'apiId': apiId,
      'apiHash': apiHash,
    };
    _sendToJS(initMsg);
  }

  Future<void> sendCode(String phoneNumber) async {
    // Wait for the GramJS client to be connected before sending
    await isReady;
    _sendToJS({
      'type': 'sendCode',
      'phoneNumber': phoneNumber,
    });
  }

  Future<void> signIn(String phoneNumber, String phoneCode) async {
    await isReady;
    _sendToJS({
      'type': 'signIn',
      'phoneNumber': phoneNumber,
      'phoneCodeHash': _phoneCodeHash,
      'phoneCode': phoneCode,
    });
  }

  Future<void> checkPassword(String password) async {
    await isReady;
    _sendToJS({
      'type': 'checkPassword',
      'password': password,
    });
  }

  String? get sessionString => _sessionString;
  Map<String, dynamic>? get userObj => _userObj;
  String? get lastRawMsg => _lastRawMsg;

  Future<Uint8List> fetchChunk({
    required int documentId,
    required String accessHash,
    required List<int> fileReference,
    required int offset,
    required int limit,
  }) async {
    await isReady;
    
    final reqId = _requestIdCounter++;
    final completer = Completer<Uint8List>();
    _pendingChunkRequests[reqId] = completer;

    _sendToJS({
      'type': 'fetchChunk',
      'requestId': reqId,
      'offset': offset,
      'limit': limit,
      'fileData': {
        'id': documentId.toString(),
        'accessHash': accessHash,
        'fileReference': base64Encode(fileReference),
      }
    });

    return completer.future;
  }

  void _sendToJS(Map<String, dynamic> msg) {
    final jsonStr = jsonEncode(msg);
    // Use single quotes to wrap the argument so JSON double-quotes pass through safely
    final escaped = jsonStr.replaceAll("\\", "\\\\").replaceAll("'", "\\'");
    _controller.runJavaScript("window.handleFlutterMessage('$escaped');");
  }
}
