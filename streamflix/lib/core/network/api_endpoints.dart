/// V1 API endpoint path constants mirroring the Reference Web Client contract
class ApiEndpoints {
  ApiEndpoints._();

  // Curated Content & Catalog Loading
  static const String curated = '/api/curated';
  static const String metadata = '/api/metadata';
  static const String search = '/api/search';

  // Details
  static const String movieDetail = '/api/metadata/:id';
  static const String tvDetail = '/api/tv/:id';

  // Streaming & Player Probing
  static const String stream = '/api/stream/:id';
  static const String streamTracks = '/api/stream/:id/tracks';
  static const String streamPartInfo = '/api/stream/:id/part-info';
  static const String streamHeartbeat = '/api/stream/:id/heartbeat';
  static const String streamEmbeddedSubtitle = '/api/stream/:id/subtitle/:streamIndex';

  // Subtitle Endpoints
  static const String externalSubtitlesList = '/api/subtitles/movie/:movieId';
  static const String externalSubtitleFile = '/api/subtitles/file/:subtitleId';

  // Legacy/Current compatibility Endpoints
  static const String movies = '/api/movies';
  static const String legacyLibrary = '/api/movies/library';
  static const String movieMetadata = '/api/movies/:id/metadata';
  static const String movieThumbnail = '/api/movies/:id/thumbnail';
  static const String movieMediaInfo = '/api/movies/:id/media-info';
  static const String moviesByGenre = '/api/home/genre/:id';
  static const String trending = '/api/home/trending';
  static const String topRated = '/api/home/top-rated';
  static const String popular = '/api/home/popular';
  static const String genresList = '/api/home/genres';

  // Static assets paths on V1 Server
  static String moviePosterStatic(String fileId) => '/data/posters/$fileId.jpg';
  static String movieBackdropStatic(String fileId) => '/data/backdrops/${fileId}_bd.jpg';
  static String movieLogoStatic(String fileId) => '/data/logos/${fileId}_logo.png';
}
