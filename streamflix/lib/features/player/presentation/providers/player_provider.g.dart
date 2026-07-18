// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for video player instance with full streaming pipeline

@ProviderFor(MoviePlayer)
final moviePlayerProvider = MoviePlayerFamily._();

/// Provider for video player instance with full streaming pipeline
final class MoviePlayerProvider
    extends $NotifierProvider<MoviePlayer, PlayerState> {
  /// Provider for video player instance with full streaming pipeline
  MoviePlayerProvider._({
    required MoviePlayerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'moviePlayerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$moviePlayerHash();

  @override
  String toString() {
    return r'moviePlayerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MoviePlayer create() => MoviePlayer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MoviePlayerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$moviePlayerHash() => r'149212a46c5897fd908fec82486d98c7930fabba';

/// Provider for video player instance with full streaming pipeline

final class MoviePlayerFamily extends $Family
    with
        $ClassFamilyOverride<
          MoviePlayer,
          PlayerState,
          PlayerState,
          PlayerState,
          String
        > {
  MoviePlayerFamily._()
    : super(
        retry: null,
        name: r'moviePlayerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for video player instance with full streaming pipeline

  MoviePlayerProvider call(String movieId) =>
      MoviePlayerProvider._(argument: movieId, from: this);

  @override
  String toString() => r'moviePlayerProvider';
}

/// Provider for video player instance with full streaming pipeline

abstract class _$MoviePlayer extends $Notifier<PlayerState> {
  late final _$args = ref.$arg as String;
  String get movieId => _$args;

  PlayerState build(String movieId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlayerState, PlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerState, PlayerState>,
              PlayerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
