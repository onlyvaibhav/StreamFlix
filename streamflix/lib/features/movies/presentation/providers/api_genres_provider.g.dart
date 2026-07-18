// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_genres_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(apiGenres)
final apiGenresProvider = ApiGenresProvider._();

final class ApiGenresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CuratedGenreItem>>,
          List<CuratedGenreItem>,
          FutureOr<List<CuratedGenreItem>>
        >
    with
        $FutureModifier<List<CuratedGenreItem>>,
        $FutureProvider<List<CuratedGenreItem>> {
  ApiGenresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiGenresProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiGenresHash();

  @$internal
  @override
  $FutureProviderElement<List<CuratedGenreItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CuratedGenreItem>> create(Ref ref) {
    return apiGenres(ref);
  }
}

String _$apiGenresHash() => r'd13614e6418a002a64ffa0665ac70b1abc4106e5';
