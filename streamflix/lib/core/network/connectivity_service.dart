import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    // If the list contains at least one connection that is not 'none'
    return results.any((result) => result != ConnectivityResult.none);
  });
});

final isOfflineProvider = Provider<bool>((ref) {
  final connectivityStream = ref.watch(connectivityProvider);
  return connectivityStream.when(
    data: (hasConnection) => !hasConnection,
    loading: () => false,
    error: (_, __) => false,
  );
});
