import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingState extends _$OnboardingState {
  @override
  bool build() {
    final box = Hive.box('authBox');
    return box.get('has_seen_onboarding', defaultValue: false) as bool;
  }

  Future<void> completeOnboarding() async {
    final box = Hive.box('authBox');
    await box.put('has_seen_onboarding', true);
    state = true;
  }
}
