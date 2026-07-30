# StreamFlix

<br/>
<div align="center">
<a href="https://github.com/onlyvaibhav/StreamFlix.git">
<img src="logo/Logo.png" alt="Logo" width="700" height="175">
</a>

<h3 align="center">StreamFlix</h3>
<h4 align="center"><a href="https://streamflix-a0l5.onrender.com/">🔴 View Live Web Project</a></h4>

  <p align="center">
    A fully-featured, Netflix-like streaming platform that uses Telegram as a highly scalable backend storage server.
    <br/>
    <br/>
    <a href="#-screenshots--preview"><strong>View Screenshots »</strong></a>
    ·
    <a href="#-features">Explore Features</a>
    ·
    <a href="#-getting-started">Getting Started</a>
    ·
    <a href="#-tech-stack">Tech Stack</a>
  </p>
</div>

---

## 📸 Screenshots & Preview

### 🌐 Web Client SPA

| Web Home Page |
| :---: |
| <img src="screenshots/Web_Home_Page.png" width="850" alt="Web Home Page"> |

<br/>

| Web Genres Page | Telegram Login Overlay |
| :---: | :---: |
| <img src="screenshots/Web_Genres_Page.png" width="420" alt="Web Genres Page"> | <img src="screenshots/Web_Login_Page.png" width="420" alt="Web Login Page"> |

### 📱 Cross-Platform Flutter App
| App Home Screen | App Genres Screen |
| :---: | :---: |
| <img src="screenshots/App_Home_Page.jpg" width="320" alt="App Home Screen"> | <img src="screenshots/App_Genres_Page.jpg" width="320" alt="App Genres Screen"> |

| Offline Downloads | App Profile & Settings |
| :---: | :---: |
| <img src="screenshots/App_Download_Page.jpg" width="320" alt="Offline Downloads"> | <img src="screenshots/App_Profile%20Page.jpg" width="320" alt="App Profile Screen"> |

---

## 🚀 About The Project

StreamFlix is a self-hosted streaming video platform delivering a premium, minimalist, Netflix-like user experience. It provides **two** fully-featured frontend clients (a Vanilla Web SPA and a cross-platform Flutter App) paired with an advanced Express.js backend designed to leverage the unlimited storage capabilities of Telegram. By utilizing Telegram channels as a content delivery network (CDN) and storage backend, StreamFlix bypasses traditional hosting limitations.

It gracefully handles everything from on-the-fly video remuxing and DASH streaming to automatic TMDB metadata fetching, multi-track subtitle syncing, offline playback, and robust stream auto-recovery for the ultimate resilient streaming experience.

---

## ✨ Features

### 🎬 Universal Features (Web & App)
- **Netflix-like UI:** A beautiful, highly responsive, and dynamic frontend featuring smooth animations, hero carousels, category filters, and grid layouts.
- **Telegram Video Streaming:** Streams media formats on-the-fly directly from Telegram channels. No need to download the full file before playing.
- **Library & Genre Browsing:** Seamlessly browse categorized content (Movies, TV Series, Genres) and perform instant search queries.
- **Multi-audio & Subtitle Management:** Dynamically switch between multiple embedded audio tracks, subtitles, and external subtitle SRT/VTT files with default language selection.
- **Support Unsupported Audio (EAC3/DTS):** Automatically detects unsupported audio codecs and transcodes EAC3/DTS to AAC on-the-fly.
- **Smart Playback & Watch Progress Sync:** Automatically saves and syncs watch positions across web and app clients, handling offline progress saves and cross-device resuming seamlessly.
- **Next Episode Auto Navigation:** Jump to the next episode in a TV series automatically upon episode completion.

### 🌐 Web Client (`public/`)
- **Vanilla DOM-Driven Rendering:** Lightweight, zero-framework JavaScript (SPA) for blazing fast load times and clean component mounting.
- **Custom Player Overlay:** Sophisticated HTML5 video player overlay featuring play/pause, seek bar, volume, speed controls, fullscreen, and keyboard shortcuts (Space, K, F, M, Arrow Keys).
- **Interactive Help & Support Pages:** Full **Help Center** with FAQ categories & search, **Contact Us** form with direct backend email & Telegram bot integration, plus Terms of Service and Privacy Policy modals.
- **DASH Processing:** Integrated adaptive streaming using `dash.js`.

### 📱 Flutter App (`streamflix/`)
- **Cross-Platform:** Write once, run on Android, iOS, Windows, macOS, Linux, and Web.
- **Offline Download Manager:** Download media files for offline viewing with intelligent progress sync when reconnected to the internet.
- **Bulletproof Streaming Engine:** Smart 3-strike auto-retry system gracefully handles Telegram DC migrations and expired file references behind the scenes without interrupting video playback.
- **Background Suspension Recovery:** Intelligently intercepts fake EOF states caused by minimizing the app, seamlessly restoring your stream from your exact last known position upon resuming.
- **Stateless Subtitles & Error Handling:** External subtitles are fetched via stateless base64url payloads with non-intrusive error toasts for non-fatal stream warnings.
- **Advanced Media Player:** Powered by `media_kit` (FFmpeg) with hardware decoding fallback mechanisms.

### 🤖 Telegram Admin Bot
- **Real-Time Alerts:** Receives instant notifications for logins, security events, and contact form submissions.
- **Bot Commands:** Control and inspect your streaming platform right from Telegram:
  - `/messages` — View all submitted user inquiries & messages
  - `/stats` — View today's logins and active viewer metrics
  - `/activenow` — List active stream sessions in real time
  - `/recentlogins` — Review recent device authorization logs

---

## 🏗 Architecture

The project consists of a detached Node.js backend acting as a proxy/CDN, serving data to two distinct frontends:

- **Backend (Express.js):** Acts as a bridge between the Telegram MTProto API (via GramJS) and standard HTTP requests. It proxies byte ranges, extracts metadata, fetches subtitles, logs events, and caches chunks in memory.
- **Frontend (Web Client):** Built as a Single Page Application (SPA) utilizing vanilla web technologies and the browser History API for routing.
- **Frontend (Flutter App):** Built entirely with Flutter, enabling high-performance rendering. Utilizes `flutter_riverpod` for responsive, decoupled state management, and `media_kit` (FFmpeg-based) for near-native video performance.

---

## 🛠 Tech Stack

**Frontend (Web Client)**
* Vanilla HTML5 & Vanilla CSS3
* Vanilla JavaScript (ES6+)
* HTML5 Video & `dash.js`

**Frontend (Flutter App)**
* [Flutter](https://flutter.dev/) & Dart
* `flutter_riverpod` (State Management)
* `media_kit` (Advanced FFmpeg-based Video Player)
* `go_router` (Routing)

**Backend (Node.js)**
* [Node.js](https://nodejs.org/) & [Express.js](https://expressjs.com/)
* [MTProto (gramjs)](https://github.com/gram-js/gramjs) for interacting natively with the Telegram API
* [Telegram Bot API](https://core.telegram.org/bots/api) for administrative alerts & management commands
* [FFmpeg](https://ffmpeg.org/) for media processing, adaptive streaming, and on-the-fly remuxing
* Memory LRU-Cache for chunk optimization

---

## 🔌 API Overview

StreamFlix is designed with a detached backend that adheres to the following REST API contracts:

- `/api/metadata` (or fallback `/api/movies/library`) - Provides initial library data including movies, TV shows, hero items, and genre-based rows.
- `/api/search?q=...` - Returns library items matching the search query.
- `/api/metadata/:fileId` - Fetches detailed information for a specific movie.
- `/api/tv/:tmdbId` - Fetches detailed data for a specific TV show, including seasons and episodes.
- `/api/stream/:fileId` - Main media stream endpoint for playback.
- `/api/stream/:fileId/tracks` - Returns available audio and subtitle tracks, stream duration, and flags.
- `/api/stream/:fileId/subtitle/:streamIndex` - Serves embedded subtitles for specified stream index.
- `/api/subtitles/movie/:fileId` - Lists available external subtitle options.
- `/api/subtitles/file/:subtitleId` - Fetches raw text (SRT/VTT) of an external subtitle.
- `/api/contact` - Submits user inquiry messages to Telegram admin bot.
- `/api/progress` - GET/POST endpoint to fetch and save watch progress.
- `/api/stream/:fileId/heartbeat` - Pinged during active playback to notify the server that the stream session is alive.

---

## 🏁 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

1. **Telegram API Credentials**
   * Go to [my.telegram.org](https://my.telegram.org)
   * Create an application and note your `api_id` and `api_hash`.
2. **Telegram Bot** *(Recommended)*
   * Talk to [@BotFather](https://t.me/BotFather) on Telegram and create a new bot to get a token.
   * Add this bot to your private channel as an admin.
3. **Private Channel**
   * Create a private Telegram channel and upload your movies/shows as video files.
   * Note the channel ID (format: `-100XXXXXXXXXX`).
4. **System Requirements**
   * `Node.js >= 18.0.0`
   * `FFmpeg` installed on your host machine
   * `Flutter SDK` (for building the app)

### Installation

#### 1. Setup the Backend
1. **Clone the repository:**
   ```bash
   git clone https://github.com/vaibhav-btc/Telegram_Streaming.git
   cd StreamFlix
   ```
2. **Install dependencies:**
   ```bash
   npm install
   ```
3. **Configure Environment:** 
   Duplicate `.env.example` to `.env` and fill in your details (API IDs, TMDB keys, etc.).
   ```bash
   cp .env.example .env
   ```
4. **Start the backend server:**
   ```bash
   npm run dev
   ```

#### 2. Run the Web Client
1. Open a new terminal.
2. Serve the `public/` directory via any static file server:
   ```bash
   npx serve public/
   ```
3. Navigate to `http://localhost:3000` (or whichever port your static server specifies).

#### 3. Run the Flutter App
1. Open a new terminal.
2. Navigate to the `streamflix` directory and run the app:
   ```bash
   cd streamflix
   flutter pub get
   flutter run -d chrome  # or run on Android/iOS/Windows
   ```

*(Alternatively, you can run the entire backend via Docker Compose using `docker-compose up --build -d`)*

---

## ⚙️ Configuration

The application is highly configurable via the `.env` file located in the root directory.

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `TELEGRAM_API_ID` | Your Telegram API ID | `1234567` |
| `TELEGRAM_API_HASH` | Your Telegram API Hash | `abc123def456...` |
| `TELEGRAM_SESSION_STRING` | Base64 Session string | `1BQA...` |
| `TELEGRAM_CHANNEL_ID` | Target Telegram channel | `-1001752608946` |
| `TELEGRAM_BOT_TOKEN` | Your BotFather token | `123:ABC...` |
| `TELEGRAM_ADMIN_CHAT_ID` | Telegram Chat ID for Admin Bot | `987654321` |
| `TMDB_API_KEY` | TMDB API Key for metadata | `d5f8...` |
| `MAX_CACHE_SIZE` | Memory size limit for chunks | `104857600` |

---

## 📁 Project Structure

- `backend/` *(Root directory)* - Contains the Express.js server, GramJS MTProto proxy, FFmpeg transcoders, and memory LRU caches.
- `public/` - Web Client SPA. Contains `index.html`, `app.js`, styles, and static assets.
- `streamflix/` - Flutter App source code. `lib/` contains screens, providers (`riverpod`), and the `media_kit` video player.
- `screenshots/` - Showcase screenshots of Web SPA and Flutter App screens.
- `controllers/` & `routes/` - Node.js API route handlers for stream logic, metadata fetching, and subtitle extraction.
- `services/bot/` - Telegram Admin Bot service for real-time notifications and `/messages`, `/stats`, `/activenow` bot commands.

---

## ⚠️ Known Issues / Limitations

- **Remuxing Limitations:** If the backend utilizes FFmpeg remuxing on-the-fly to handle incompatible native codecs, seeking may introduce momentary audio/video sync offsets tied to keyframe precision.
- **Unsupported Audio:** Some original audio codecs (e.g., EAC3 or specific DTS builds) may lack native browser support. The system transcodes EAC3/DTS to AAC on-the-fly.
- **Autoplay Restrictions (Web):** Browsers restrict autoplaying videos with sound. The custom player requires user interaction to initialize un-muted playback.
- **Subtitle Desync:** If Audio switches from default to non-default, you might experience subtitle desync. Use Quick Sync features in the player to re-align them.

---

## ⚠️ Disclaimer

This project is for educational and personal use only. Streaming copyrighted content without permission is illegal. The maintainers of this repository are not responsible for how this software is used.

---

## 🤝 Contributing

Contributions are welcome! If you plan to introduce new components, please adhere to:
- Keeping dependencies zero for the Web Client frontend (no React/Vue/Svelte).
- Using Flutter Best Practices for the App frontend.

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

<br>
<div align="center">
  <i>Built with ❤️ by Vaibhav</i>
</div>
