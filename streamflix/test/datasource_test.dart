import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:streamflix/features/movies/data/datasources/movie_remote_datasource.dart';

void main() {
  test('MovieRemoteDataSource gets more like this', () async {
    final dio = Dio();
    dio.options.baseUrl = 'http://localhost:5000';
    
    final dataSource = MovieRemoteDataSource(dio);
    
    final movies = await dataSource.getMoreLikeThis('1157', 'movie');
    
    print('==============================');
    print('FLUTTER CONSOLE LOG:');
    print('Fetched ${movies.length} recommendations from live endpoint.');
    for (final m in movies) {
      print(' - ${m.title} (ID: ${m.id}, Type: ${m.type})');
    }
    print('==============================');
    
    expect(movies, isNotNull);
  });
}
