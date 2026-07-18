/// Named route constants for type-safe navigation
class RouteNames {
  RouteNames._();

  static const String home = '/';
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String movies = '/movies';
  static const String tvShows = '/tv-shows';
  static const String search = '/search';
  static const String genres = '/genres';
  static const String downloads = '/downloads';
  static const String profile = '/profile';
  static const String movieDetail = '/movie/:id';
  static const String watch = '/watch/:id';
  static const String genreDetail = '/genre/:slug';

  static const String seriesDownloads = 'series/:seriesId';
  
  // Utility methods
  static String movieDetailPath(String movieId) => '/movie/$movieId';
  static String watchPath(String movieId) => '/watch/$movieId';
  static String genreDetailPath(String slug) => '/genre/$slug';
  static String seriesDownloadsPath(String seriesId) => '/downloads/series/$seriesId';
}
