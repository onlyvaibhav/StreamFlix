# StreamFlix V1 API Contract

## Base URL
- Development (Local Web): `http://localhost:3000`
- Development (Android LAN): `http://192.168.x.x:3000` (Private machine IP)

---

## 1. Authentication Endpoints

### POST `/api/auth/login`
- **Method**: POST
- **Request Body**:
  ```json
  {
    "phone": "+123456789",
    "password": "my_password"
  }
  ```
- **Response**: JWT Session token payload.

---

## 2. Catalog / Movies Endpoints

### GET `/api/movies`
- **Method**: GET
- **Query Parameters**:
  - `limit`: int (default `50`)
  - `offset`: int (default `0`)
  - `search`: string (optional search query)
- **Response**:
  ```json
  {
    "success": true,
    "count": 2,
    "nextOffset": 102,
    "movies": [
      {
        "id": "1000",
        "title": "I, Robot",
        "fileName": "I_Robot_2004.mkv",
        "type": "movie",
        "overview": "In 2035...",
        "year": 2004,
        "runtime": 115,
        "genres": ["Action", "Science Fiction"],
        "rating": 6.965,
        "popularity": 9.2619,
        "poster": "/data/posters/1000.jpg",
        "backdrop": "/data/backdrops/1000_bd.jpg",
        "logo": "/data/logos/1000_logo.png",
        "tmdbId": 2048,
        "isSplit": false,
        "parts": null
      }
    ]
  }
  ```

### GET `/api/movies/library`
- **Method**: GET
- **Response**: Returns categorized list for layout rendering.
  ```json
  {
    "success": true,
    "counts": {
      "movies": 45,
      "tvShows": 12
    },
    "movies": [...],
    "tvShows": [
      {
        "showTitle": "Snow White with the Red Hair",
        "showTmdbId": 63087,
        "poster": "/data/posters/show_63087.jpg",
        "backdrop": "/data/backdrops/show_63087_bd.jpg",
        "rating": 7.662,
        "year": 2015,
        "genres": ["Animation", "Drama"],
        "overview": "Shirayuki is a young girl...",
        "availableEpisodeCount": 24
      }
    ],
    "heroItems": [...],
    "genreRows": [
      {
        "genre": "Action",
        "items": [...]
      }
    ]
  }
  ```

### GET `/api/movies/:id`
- **Method**: GET
- **Path Parameter**: `id` (Message ID of target movie/episode)
- **Response**:
  ```json
  {
    "success": true,
    "movie": {
      "id": "1000",
      "title": "I, Robot",
      ...
    }
  }
  ```

---

## 3. Streaming Endpoints

### GET `/api/stream/:id`
- **Method**: GET
- **Path Parameter**: `id` (Message ID)
- **Request Headers**:
  - `Range`: `bytes=START-END` (e.g. `bytes=0-1048575` to request a 1MB chunk)
- **Response Headers**:
  - `Content-Type`: `video/mp4` or appropriate video MIME type
  - `Accept-Ranges`: `bytes`
  - `Content-Length`: size of requested chunk
  - `Content-Range`: `bytes START-END/TOTAL_SIZE`
- **Response Body**: Video chunk bytes.

### GET `/api/stream/:id/heartbeat`
- **Method**: GET
- **Path Parameter**: `id` (Message ID)
- **Response**: Status `204 No Content`. Keeps streaming activity registered on server.

---

## 4. Subtitle Endpoints

### GET `/api/subtitles/movie/:movieId`
- **Method**: GET
- **Path Parameter**: `movieId`
- **Response**: List of external subtitles.
  ```json
  [
    {
      "subtitleId": "sub_123",
      "language": "English",
      "languageCode": "eng",
      "url": "/api/subtitles/file/sub_123"
    }
  ]
  ```

### GET `/api/subtitles/file/:subtitleId`
- **Method**: GET
- **Path Parameter**: `subtitleId`
- **Response**: Plain VTT text file bytes with CORS headers.
