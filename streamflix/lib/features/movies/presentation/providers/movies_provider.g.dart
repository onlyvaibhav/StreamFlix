// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movies_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for all movies list

@ProviderFor(allMovies)
final allMoviesProvider = AllMoviesProvider._();

/// Provider for all movies list

final class AllMoviesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Movie>>,
          List<Movie>,
          FutureOr<List<Movie>>
        >
    with $FutureModifier<List<Movie>>, $FutureProvider<List<Movie>> {
  /// Provider for all movies list
  AllMoviesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allMoviesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allMoviesHash();

  @$internal
  @override
  $FutureProviderElement<List<Movie>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Movie>> create(Ref ref) {
    return allMovies(ref);
  }
}

String _$allMoviesHash() => r'2457788d1475e8a893d1ecfb807cfa21d7e408f1';

/// Provider for featured movies (hero banner)

@ProviderFor(featuredMovies)
final featuredMoviesProvider = FeaturedMoviesProvider._();

/// Provider for featured movies (hero banner)

final class FeaturedMoviesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Movie>>,
          List<Movie>,
          FutureOr<List<Movie>>
        >
    with $FutureModifier<List<Movie>>, $FutureProvider<List<Movie>> {
  /// Provider for featured movies (hero banner)
  FeaturedMoviesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featuredMoviesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featuredMoviesHash();

  @$internal
  @override
  $FutureProviderElement<List<Movie>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Movie>> create(Ref ref) {
    return featuredMovies(ref);
  }
}

String _$featuredMoviesHash() => r'52e91df688d98977878f8322c678fe9a7b7b4eab';

/// Provider for movies by genre

@ProviderFor(moviesByGenre)
final moviesByGenreProvider = MoviesByGenreFamily._();

/// Provider for movies by genre

final class MoviesByGenreProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Movie>>,
          List<Movie>,
          FutureOr<List<Movie>>
        >
    with $FutureModifier<List<Movie>>, $FutureProvider<List<Movie>> {
  /// Provider for movies by genre
  MoviesByGenreProvider._({
    required MoviesByGenreFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'moviesByGenreProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$moviesByGenreHash();

  @override
  String toString() {
    return r'moviesByGenreProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Movie>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Movie>> create(Ref ref) {
    final argument = this.argument as String;
    return moviesByGenre(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MoviesByGenreProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$moviesByGenreHash() => r'd1ce64775bf3f39956ab3ce06425d9de176145f7';

/// Provider for movies by genre

final class MoviesByGenreFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Movie>>, String> {
  MoviesByGenreFamily._()
    : super(
        retry: null,
        name: r'moviesByGenreProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for movies by genre

  MoviesByGenreProvider call(String genreId) =>
      MoviesByGenreProvider._(argument: genreId, from: this);

  @override
  String toString() => r'moviesByGenreProvider';
}

/// Provider for single movie detail or TV show detail adapted to Movie model

@ProviderFor(movieDetail)
final movieDetailProvider = MovieDetailFamily._();

/// Provider for single movie detail or TV show detail adapted to Movie model

final class MovieDetailProvider
    extends $FunctionalProvider<AsyncValue<Movie>, Movie, FutureOr<Movie>>
    with $FutureModifier<Movie>, $FutureProvider<Movie> {
  /// Provider for single movie detail or TV show detail adapted to Movie model
  MovieDetailProvider._({
    required MovieDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailHash();

  @override
  String toString() {
    return r'movieDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Movie> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Movie> create(Ref ref) {
    final argument = this.argument as String;
    return movieDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailHash() => r'28f8420ae1a3f9062c14d3df934ffc4bfe0602b2';

/// Provider for single movie detail or TV show detail adapted to Movie model

final class MovieDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Movie>, String> {
  MovieDetailFamily._()
    : super(
        retry: null,
        name: r'movieDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for single movie detail or TV show detail adapted to Movie model

  MovieDetailProvider call(String movieId) =>
      MovieDetailProvider._(argument: movieId, from: this);

  @override
  String toString() => r'movieDetailProvider';
}

/// Provider for grouped movies by genre

@ProviderFor(moviesGroupedByGenre)
final moviesGroupedByGenreProvider = MoviesGroupedByGenreProvider._();

/// Provider for grouped movies by genre

final class MoviesGroupedByGenreProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<Movie>>>,
          Map<String, List<Movie>>,
          FutureOr<Map<String, List<Movie>>>
        >
    with
        $FutureModifier<Map<String, List<Movie>>>,
        $FutureProvider<Map<String, List<Movie>>> {
  /// Provider for grouped movies by genre
  MoviesGroupedByGenreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moviesGroupedByGenreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moviesGroupedByGenreHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<Movie>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<Movie>>> create(Ref ref) {
    return moviesGroupedByGenre(ref);
  }
}

String _$moviesGroupedByGenreHash() =>
    r'0c63f99389ca06e40ac8b1ae807703d52c4c3016';

/// Provider for curated content (homepage sections)

@ProviderFor(curatedContent)
final curatedContentProvider = CuratedContentProvider._();

/// Provider for curated content (homepage sections)

final class CuratedContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<CuratedResponse>,
          CuratedResponse,
          FutureOr<CuratedResponse>
        >
    with $FutureModifier<CuratedResponse>, $FutureProvider<CuratedResponse> {
  /// Provider for curated content (homepage sections)
  CuratedContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedContentHash();

  @$internal
  @override
  $FutureProviderElement<CuratedResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CuratedResponse> create(Ref ref) {
    return curatedContent(ref);
  }
}

String _$curatedContentHash() => r'd02e6c97114b8577551ccf3e8d446418025d355e';

/// Provider for TV show details

@ProviderFor(tvShowDetail)
final tvShowDetailProvider = TvShowDetailFamily._();

/// Provider for TV show details

final class TvShowDetailProvider
    extends $FunctionalProvider<AsyncValue<TvShow>, TvShow, FutureOr<TvShow>>
    with $FutureModifier<TvShow>, $FutureProvider<TvShow> {
  /// Provider for TV show details
  TvShowDetailProvider._({
    required TvShowDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tvShowDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tvShowDetailHash();

  @override
  String toString() {
    return r'tvShowDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TvShow> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TvShow> create(Ref ref) {
    final argument = this.argument as String;
    return tvShowDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TvShowDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tvShowDetailHash() => r'2b4254262bcff319458f1c989b03b5069fda7b5b';

/// Provider for TV show details

final class TvShowDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TvShow>, String> {
  TvShowDetailFamily._()
    : super(
        retry: null,
        name: r'tvShowDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for TV show details

  TvShowDetailProvider call(String showTmdbId) =>
      TvShowDetailProvider._(argument: showTmdbId, from: this);

  @override
  String toString() => r'tvShowDetailProvider';
}

/// Provider for relevance catalog searching

@ProviderFor(searchCatalog)
final searchCatalogProvider = SearchCatalogFamily._();

/// Provider for relevance catalog searching

final class SearchCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Movie>>,
          List<Movie>,
          FutureOr<List<Movie>>
        >
    with $FutureModifier<List<Movie>>, $FutureProvider<List<Movie>> {
  /// Provider for relevance catalog searching
  SearchCatalogProvider._({
    required SearchCatalogFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchCatalogProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchCatalogHash();

  @override
  String toString() {
    return r'searchCatalogProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Movie>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Movie>> create(Ref ref) {
    final argument = this.argument as String;
    return searchCatalog(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchCatalogProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchCatalogHash() => r'60ca067a593c127317019dac2a03fb573f44ecfb';

/// Provider for relevance catalog searching

final class SearchCatalogFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Movie>>, String> {
  SearchCatalogFamily._()
    : super(
        retry: null,
        name: r'searchCatalogProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for relevance catalog searching

  SearchCatalogProvider call(String query) =>
      SearchCatalogProvider._(argument: query, from: this);

  @override
  String toString() => r'searchCatalogProvider';
}

/// Provider for list of all TV shows grouped from metadata index

@ProviderFor(allTvShows)
final allTvShowsProvider = AllTvShowsProvider._();

/// Provider for list of all TV shows grouped from metadata index

final class AllTvShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Movie>>,
          List<Movie>,
          FutureOr<List<Movie>>
        >
    with $FutureModifier<List<Movie>>, $FutureProvider<List<Movie>> {
  /// Provider for list of all TV shows grouped from metadata index
  AllTvShowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allTvShowsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allTvShowsHash();

  @$internal
  @override
  $FutureProviderElement<List<Movie>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Movie>> create(Ref ref) {
    return allTvShows(ref);
  }
}

String _$allTvShowsHash() => r'a2d3d88b70bc6cb241ff43b808751435e62c9be8';

/// Provider for managing and retrieving watch progress history

@ProviderFor(ContinueWatching)
final continueWatchingProvider = ContinueWatchingProvider._();

/// Provider for managing and retrieving watch progress history
final class ContinueWatchingProvider
    extends $NotifierProvider<ContinueWatching, List<WatchHistoryItem>> {
  /// Provider for managing and retrieving watch progress history
  ContinueWatchingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueWatchingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueWatchingHash();

  @$internal
  @override
  ContinueWatching create() => ContinueWatching();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<WatchHistoryItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<WatchHistoryItem>>(value),
    );
  }
}

String _$continueWatchingHash() => r'bbcd3e67db3366a24c963e89109491c8f9c82989';

/// Provider for managing and retrieving watch progress history

abstract class _$ContinueWatching extends $Notifier<List<WatchHistoryItem>> {
  List<WatchHistoryItem> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<List<WatchHistoryItem>, List<WatchHistoryItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<WatchHistoryItem>, List<WatchHistoryItem>>,
              List<WatchHistoryItem>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
