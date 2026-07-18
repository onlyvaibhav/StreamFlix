import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/network/dio_client.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthState extends _$AuthState {
  @override
  bool build() {
    final box = Hive.box('authBox');
    final session = box.get('telegram_session') as String?;

    // Auto-logout if the active session is revoked during playback or requests
    final sub = TelegramClientService().authStateStream.listen((event) {
      if (event == 'error:revoked') {
        logout(isRevoked: true);
      }
    });
    ref.onDispose(() => sub.cancel());

    return session != null && session.isNotEmpty;
  }

  void login(String sessionString) {
    Hive.box('authBox').put('telegram_session', sessionString);
    state = true;
  }

  Future<void> logout({bool isRevoked = false}) async {
    // Fire and forget the backend logout so the UI redirects instantly
    try {
      final dio = ref.read(dioProvider);
      dio.post('/api/auth/telegram/logout', data: {'status': isRevoked ? 'revoked' : 'logout'});
    } catch (e) {
      // Ignore
    }

    Hive.box('authBox').delete('telegram_session');
    Hive.box('authBox').delete('sessionToken');
    Hive.box('authBox').delete('user');
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    
    state = false;
  }
}
