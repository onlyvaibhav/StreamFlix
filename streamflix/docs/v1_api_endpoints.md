# StreamFlix V1 Discovered API Endpoints

This document outlines the API endpoints discovered by inspecting the V1 backend codebase (`routes/` and `controllers/` directories).

## 1. Authentication Endpoints (`routes/authRoutes.js`)
* **POST `/api/auth/login`**: Authenticate and initiate a Telegram session.
* **GET `/api/auth/guest-token`**: Generate guest access session tokens.

## 2. Admin & Worker Endpoints (`routes/adminRoutes.js`)
* **GET `/api/admin/worker-status`**: Check background worker parsing tasks status.
* **POST `/api/admin/worker/pause`**: Pause metadata background indexing operations.
* **POST `/api/admin/worker/resume`**: Resume background scanning operations.

## 3. Catalog / Movies Endpoints (`routes/movieRoutes.js`)
* **GET `/api/movies`**: 
  - Query parameters: `limit` (default: 50), `offset` (default: 0), `search` (optional keyword).
  - Returns mixed media array (split parts grouped, TV shows grouped under `'tv_show'`).
* **GET `/api/movies/library`**:
  - Main dashboard layout resolver.
  - Returns `{ success: true, counts: { movies, tvShows }, movies, tvShows, heroItems, genreRows }`.
* **GET `/api/movies/cache-stats`**: Fetch LRU memory cache storage counts.
* **GET `/api/movies/:id`**: Fetch detailed info for a single movie file (by Telegram message ID).
* **GET `/api/movies/:id/metadata`**: Get the raw parsed/TMDB `metadata.json` data.
* **GET `/api/movies/:id/thumbnail`**: Stream poster or episode thumbnail bytes.
* **GET `/api/movies/:id/media-info`**: Run probes or fetch formats, video tracks, and formats description.

## 4. Video Streaming Endpoints (`routes/streamRoutes.js`)
* **GET `/api/stream/:id`**: Main binary range streaming endpoint.
* **GET `/api/stream/:id/transmux`**: Transmux container wrappers for MKV/AVI files to support standard browser video tags.
* **GET `/api/stream/:id/seek`**: Time-based seek inside custom transmux stream threads.
* **GET `/api/stream/:id/tracks`**: Auto-detect embedded audio tracks and sub tracks.
* **GET `/api/stream/:id/subtitle/:streamIndex`**: Extract and convert embedded subtitle streams.
* **GET `/api/stream/:id/heartbeat`**: Ping tracking session keep-alive.

## 5. External Subtitle Endpoints (`routes/subtitleRoutes.js`)
* **GET `/api/subtitles/movie/:movieId`**: Auto-searches External (SubDL/OpenSubtitles) APIs for matches.
* **GET `/api/subtitles/file/:subtitleId`**: Serves/downloads specific VTT subtitle tracks.
* **GET `/api/subtitles/search/:query`**: Performs custom title subtitle search runs.
* **POST `/api/subtitles/convert`**: Converts formats.
* **GET `/api/subtitles/test/sample.vtt`**: Static VTT subtitle cue tracks mock.

## 6. Mirroring TMDB Home API Endpoints (`routes/homeRoutes.js`)
* **GET `/api/home/trending`**: Mirror TMDB movie trending charts list.
* **GET `/api/home/top-rated`**: Mirror TMDB movie top-rated charts list.
* **GET `/api/home/popular`**: Mirror TMDB movie popular charts list.
* **GET `/api/home/genres`**: List all TMDB genres list objects.
* **GET `/api/home/genre/:id`**: Filter TMDB movies using specific genre filters.

## 7. TV Local & TMDB Catalog Endpoints (`routes/tvRoutes.js`)
* **GET `/api/tv/:id/details`**: Fetch TV Show details from TMDB catalog.
* **GET `/api/tv/:id/local`**: Fetch locally indexed season/episodes matching show TMDB ID.
* **GET `/api/tv/:id/season/:season`**: Fetch TV Season details from TMDB catalog.
