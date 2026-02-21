# StreamFlix

<br/>
<div align="center">
<a href="https://github.com/vaibhav-btc/Telegram_Streaming">
<!-- You can add a logo image here in the future -->
<img src="https://img.icons8.com/color/144/null/telegram-app--v1.png" alt="Logo" width="100" height="100">
</a>

<h3 align="center">StreamFlix</h3>

  <p align="center">
    A fully-featured, Netflix-like streaming platform that uses Telegram as a highly scalable backend storage server.
    <br/>
    <br/>
    <a href="#features"><strong>Explore the features »</strong></a>
    <br/>
    <br/>
    <a href="#getting-started">Getting Started</a>
    ·
    <a href="#tech-stack">Tech Stack</a>
    ·
    <a href="#configuration">Configuration</a>
  </p>
</div>

---

## 🚀 About The Project

StreamFlix is a self-hosted streaming video platform delivering a premium, minimalist, Netflix-like user experience. It provides a fully-featured Single Page Application (SPA) and an advanced HTML5 custom video player designed to consume a specific set of backend APIs, leveraging the unlimited storage capabilities of Telegram. By utilizing Telegram channels as a content delivery network (CDN) and storage backend, StreamFlix bypasses traditional hosting limitations.

It gracefully handles everything from on-the-fly video transcoding and DASH streaming to automatic TMDB metadata fetching and multi-track subtitle syncing.

### ✨ Features

- **Netflix-like UI:** A beautiful, highly responsive, and dynamic vanilla HTML/CSS/JS frontend featuring smooth animations, carousels, and grid layouts.
- **Telegram Video Streaming:** Streams media formats on-the-fly directly from Telegram channels. No need to download the full file before playing.
- **Library browsing:** Seamlessly browse categorized content (Movies, TV Shows) and perform search queries.
- **Hero carousel:** Engaging, auto-rotating hero slider for featured content with swipe navigation support.
- **Custom player:** A sophisticated, fully-custom HTML5 video player overlay featuring:
  - Play, pause, and seek functionalities.
  - 10-second skip forward/backward.
  - Volume, mute, and playback speed controls.
  - Fullscreen modes.
  - Comprehensive keyboard shortcuts (Space/K for play/pause, Arrows for seek/volume, F for fullscreen, M for mute, < / > for speed, Esc to close).
- **Multi‑audio & subtitles:** Dynamically switch between multiple embedded audio tracks, subtitles and load external subtitles (supports custom WebVTT/SRT parsing and rendering).
- **Support Unsupported Audio like EAC3:** Transcode EAC3 to AAC on-the-fly.
- **Next episode auto navigation:** Easily seamlessly jump to the next episode in a TV series.
- **Mobile gestures:** Touch-friendly controls with tap/double-tap for play/seek and swipe gestures in the hero section.
- **Smart Playback:** Resume playback from where you left off (using local storage), and automatic grouping of multi-part split movies.
- **Admin Dashboard(in progress):** Manage your streams, caches, and system directly via a unified web interface with authentication.

---

## 🏗 Architecture

This project is built as a Single Page Application (SPA) utilizing vanilla web technologies:

- **Routing:** Uses the browser History API (`history.pushState` / `popstate`) for seamless client-side routing without page reloads.
- **DOM‑driven rendering:** No heavy JavaScript frameworks (like React or Vue) are used. The UI is dynamically assembled and injected into the DOM.
- **Global Data Management:** A globally accessible `state` object tracks library data, the current route, and all playback details (file ID, seasons/episodes, selected audio/subtitles, etc.).
- **Player Overlay:** The video player is architected as a full-screen overlay rather than a separate page. Navigating to the `/play/:fileId` route simply presents the interactive player on top of the existing DOM, ensuring instant loading and smooth transitions.
- **Entry point:** The application initializes centrally in `app.js`, which wires up all event listeners, routers, and initial data fetches upon `DOMContentLoaded`.

---

## 🛠 Tech Stack

**Frontend**
* Vanilla HTML5 & CSS3 (Custom styling, Netflix aesthetics, zero heavy CSS frameworks)
* Vanilla JavaScript (ES6+, DOM manipulation without React/Vue)
* Custom HTML5 Video Player overlay with DASH processing via `dash.js`

**Backend**
* [Node.js](https://nodejs.org/) & [Express.js](https://expressjs.com/)
* [MTProto (gramjs)](https://github.com/gram-js/gramjs) for interacting natively with the Telegram API
* [FFmpeg](https://ffmpeg.org/) for media processing, adaptive streaming, and on-the-fly remuxing
* LRU-Cache for chunk optimization

**Infrastructure**
* [Docker](https://www.docker.com/) & [Docker Compose](https://docs.docker.com/compose/)

---

## 🔌 API Overview

StreamFlix is designed with a detached **frontend** relying on a backend implementation that adheres to the following REST API contracts:

- `/api/metadata` (or fallback `/api/movies/library`) - Provides the initial library data including movies, TV shows, hero items, and genre-based rows.
- `/api/search?q=...` - Returns library items matching the search query.
- `/api/metadata/:fileId` - Fetches detailed information for a specific movie.
- `/api/tv/:tmdbId` - Fetches detailed data for a specific TV show, including seasons and episodes.
- `/api/stream/:fileId` - The main media stream endpoint for playback.
- `/api/stream/:fileId/tracks` - Returns available audio and subtitle tracks, stream duration, and flags (such as `hasUnsupportedAudio`).
- `/api/stream/:fileId/subtitle/:streamIndex` - Serves embedded subtitles for the specified stream index.
- `/api/subtitles/movie/:fileId` - Lists available external subtitle options.
- `/api/subtitles/file/:subtitleId` - Fetches the raw text (SRT/VTT) of an external subtitle.
- `/api/stream/:fileId/heartbeat` - Pinged every 20 seconds during active playback to notify the server that the stream session is alive.

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
   * `FFmpeg` installed on your host machine (if running natively)
   * `Docker` (if running via containerized stack)

### Installation

#### Option 1: Using Docker (Recommended)
This approach sets up the Node backend and Nginx reverse proxy automatically.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vaibhav-btc/Telegram_Streaming.git
   cd StreamFlix
   ```
2. **Configure Environment variables:**
   Inside the `backend` folder, duplicate `.env.example` as `.env` and fill in your details (API IDs, TMDB keys, etc.).
   ```bash
   cp backend/.env.example backend/.env
   ```
3. **Start the containers:**
   ```bash
   docker-compose up --build -d
   ```
4. **Access the app:** Open `http://localhost` in your browser.

#### Option 2: Running Locally

1. **Clone & Install backend dependencies:**
   ```bash
   cd backend
   npm install
   ```
2. **Configure Environment:** Set up your `.env` file (same as above).
3. **Start the backend server** (development mode with Nodemon):
   ```bash
   npm run dev
   ```
4. **Serve the Frontend:** Open `public/index.html` via any static file server, for example:
   ```bash
   npx serve public/
   ```
5. **Access the app:** Navigate to `http://localhost:5000` (or whichever port your static server specifies).

---

## ⚙️ Configuration

The application is highly configurable via the `.env` file located in the `backend` directory.

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `TELEGRAM_API_ID` | Your Telegram API ID | `1234567` |
| `TELEGRAM_API_HASH` | Your Telegram API Hash | `abc123def456...` |
| `TELEGRAM_SESSION_STRING` | Base64 Session string | `1BQA...` |
| `TELEGRAM_CHANNEL_ID` | Target Telegram channel | `-1001752608946` |
| `TELEGRAM_BOT_TOKEN` | Your BotFather token | `123:ABC...` |
| `TMDB_API_KEY` | TMDB API Key for metadata | `d5f8...` |
| `MAX_CACHE_SIZE` | Memory size limit for chunks | `104857600` |

- **External Media Limits:** Images and posters typically utilize proxy routes or local URLs defined by the `/api` responses. If direct HTTP/HTTPS URLs are intentionally rejected by your frontend CSS styling or CSP, data must traverse your local backend proxy instead.

---

## ⏯ Player Details

- **Local Resume:** Playback progress, selected audio tracks, and selected subtitles are stored in the browser's `localStorage` under the `streamflix_playback` key, keyed by `fileId`. Entries older than 7 days are automatically pruned to conserve space.
- **Track Discovery:** Upon opening a video, the player inherently requests the `/tracks` API endpoint to inventory stream variants. It categorizes audio streams and identifies subtitles available for dynamic switching.
- **Subtitle Handling:** Expects subtitles in SRT or WebVTT formats. The UI gracefully fetches, parses cues, and renders texts into a specialized `<div id="subtitle-display">` element synchronized with the `timeupdate` event.
- **Video Decoding:** Relies on native browser decoding capabilities. H.264 video streams and AAC audio formats generally have the widest compatibility.

---

## 📁 Project Structure

- `index.html` - The core HTML skeleton, containing root container elements and overlay templates.
- `app.js` - The main workhorse containing routing logic, state management, API service fetching, DOM rendering routines, and custom player logic.
- `public/css/` or `styles.css` - Custom CSS rules handling responsive grids, hero layouts, skeleton loaders, and player UI without relying on heavy external frameworks.
- `public/` - Static assets including icons, placeholder images, and manifest files.

---

## ⚠️ Known Issues / Limitations

- **Remuxing Limitations:** If the backend utilizes FFmpeg remuxing on-the-fly to handle incompatible native codecs, seeking may introduce momentary audio/video sync offsets tied to keyframe precision.
- **Unsupported Audio:** Some original audio codecs (e.g., EAAC or specific DTS builds) may lack native browser support. The system monitors a `hasUnsupportedAudio` flag from the tracks endpoint to react if transcoding is unavoidable.
- **Autoplay Restrictions:** Browsers aggressively restrict autoplaying videos with sound. The custom player adheres to requiring human interaction to initialize un-muted playback.
- **Subtile Desync:** If Audio switch from default to non default then can experience subtitle desync.Use Quick Sync to sync subtitle with audio.

---


## ⚠️ Disclaimer

This project is for educational and personal use only. Streaming copyrighted content without permission is illegal. The maintainers of this repository are not responsible for how this software is used.

---

## 🤝 Contributing

Contributions are welcome! If you plan to introduce new components, please adhere to:
- Keeping dependencies zero for the frontend (no React/Vue/Svelte or heavy libraries).
- Using ES6+ features efficiently while retaining readability.
- Validating mobile scaling and custom player interactions on varied screen layouts.

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
