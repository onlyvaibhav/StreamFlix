// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genre_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that extracts unique genres from all movies

@ProviderFor(allGenres)
final allGenresProvider = AllGenresProvider._();

/// Provider that extracts unique genres from all movies

final class AllGenresProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Provider that extracts unique genres from all movies
  AllGenresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allGenresProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allGenresHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return allGenres(ref);
  }
}

String _$allGenresHash() => r'f538be986df9c42308091ea0525f6e4eb8673508';
