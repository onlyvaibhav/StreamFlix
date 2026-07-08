/// Named route constants for type-safe navigation
class RouteNames {
  RouteNames._();

  static const String home = '/';
  static const String login = '/login';
  static const String movies = '/movies';
  static const String tvShows = '/tv-shows';
  static const String search = '/search';
  static const String profile = '/profile';
  static const String movieDetail = '/movie/:id';
  static const String watch = '/watch/:id';

  // Utility methods
  static String movieDetailPath(String movieId) => '/movie/$movieId';
  static String watchPath(String movieId) => '/watch/$movieId';
}
