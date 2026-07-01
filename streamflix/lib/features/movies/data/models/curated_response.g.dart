// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curated_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CuratedGenreItem _$CuratedGenreItemFromJson(Map<String, dynamic> json) =>
    _CuratedGenreItem(
      name: json['name'] as String,
      slug: json['slug'] as String,
      image: json['image'] as String?,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$CuratedGenreItemToJson(_CuratedGenreItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'slug': instance.slug,
      'image': instance.image,
      'count': instance.count,
    };

_CuratedGenresPage _$CuratedGenresPageFromJson(Map<String, dynamic> json) =>
    _CuratedGenresPage(
      genres: (json['genres'] as List<dynamic>)
          .map((e) => CuratedGenreItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      sections: (json['sections'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
          k,
          (e as Map<String, dynamic>).map(
            (k, e) => MapEntry(
              k,
              (e as List<dynamic>)
                  .map((e) => Movie.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        ),
      ),
    );

Map<String, dynamic> _$CuratedGenresPageToJson(_CuratedGenresPage instance) =>
    <String, dynamic>{'genres': instance.genres, 'sections': instance.sections};

_CuratedSpecialSections _$CuratedSpecialSectionsFromJson(
  Map<String, dynamic> json,
) => _CuratedSpecialSections(
  mood: (json['mood'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      k,
      (e as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  ),
  duration: (json['duration'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      k,
      (e as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  ),
);

Map<String, dynamic> _$CuratedSpecialSectionsToJson(
  _CuratedSpecialSections instance,
) => <String, dynamic>{'mood': instance.mood, 'duration': instance.duration};

_CuratedHomepage _$CuratedHomepageFromJson(Map<String, dynamic> json) =>
    _CuratedHomepage(
      hero: (json['hero'] as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
      trending: (json['trending'] as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentlyAdded: (json['recently_added'] as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
      topRated: (json['top_rated'] as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
      rows: (json['rows'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
          k,
          (e as List<dynamic>)
              .map((e) => Movie.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ),
    );

Map<String, dynamic> _$CuratedHomepageToJson(_CuratedHomepage instance) =>
    <String, dynamic>{
      'hero': instance.hero,
      'trending': instance.trending,
      'recently_added': instance.recentlyAdded,
      'top_rated': instance.topRated,
      'rows': instance.rows,
    };

_CuratedResponse _$CuratedResponseFromJson(Map<String, dynamic> json) =>
    _CuratedResponse(
      homepage: CuratedHomepage.fromJson(
        json['homepage'] as Map<String, dynamic>,
      ),
      genresPage: CuratedGenresPage.fromJson(
        json['genres_page'] as Map<String, dynamic>,
      ),
      specialSections: CuratedSpecialSections.fromJson(
        json['special_sections'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$CuratedResponseToJson(_CuratedResponse instance) =>
    <String, dynamic>{
      'homepage': instance.homepage,
      'genres_page': instance.genresPage,
      'special_sections': instance.specialSections,
    };
