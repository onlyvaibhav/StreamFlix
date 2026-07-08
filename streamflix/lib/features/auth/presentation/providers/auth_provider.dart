import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthState extends _$AuthState {
  @override
  bool build() {
    final box = Hive.box('authBox');
    final session = box.get('telegram_session') as String?;
    return session != null && session.isNotEmpty;
  }

  void login(String sessionString) {
    Hive.box('authBox').put('telegram_session', sessionString);
    state = true;
  }

  void logout() {
    Hive.box('authBox').delete('telegram_session');
    state = false;
  }
}
