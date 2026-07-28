import 'package:dio/dio.dart';
import 'lib/features/movies/data/datasources/movie_remote_datasource.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = 'http://localhost:5000'; // Make sure the backend port is correct
  
  final dataSource = MovieRemoteDataSource(dio);
  
  try {
    print('Testing More Like This for Spider-Man (1157)...');
    final movies = await dataSource.getMoreLikeThis('1157', 'movie');
    
    print('Success! Received ${movies.length} recommendations:');
    for (final m in movies) {
      print('- ${m.title} (ID: ${m.id})');
    }
    
  } catch (e) {
    print('Failed: $e');
  }
}
