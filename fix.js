const fs = require('fs');
let code = fs.readFileSync('public/js/app.js', 'utf8');

const regex = /body\.innerHTfunction renderMovieModal[\s\S]*?<button class="btn-premium-play" onclick="playVideo\(\{fileId: '\$\{playFileId\}', title: '\$\{escArg\(movieTitle\)\}', _useStoredParts: \$\{isSplit\}\}\)">/g;

const replacement = \ody.innerHTML = '<div class="empty-state"><h2>Content not found</h2></div>';
  }
}

function renderMovieModal(container, movie) {
  const isSplit = movie.isSplit && movie.parts && movie.parts.length > 1;
  const backdrop = backdropSrc(movie.backdrop) || posterSrc(movie.poster);

  const metaItems = [
    movie.year,
    movie.runtime ? fmtRuntime(movie.runtime) : null,
  ].filter(Boolean);

  if (isSplit) {
    window._pendingMovieParts = movie.parts;
  } else {
    window._pendingMovieParts = null;
  }

  const playFileId = movie.fileId || (isSplit ? movie.parts[0].fileId : '');
  const movieTitle = getItemTitle(movie);
  const logoUrl = movie.logo;
  const logoHtml = isValidLogo(logoUrl)
    ? \\\<img src="\" alt="\" class="modal-logo" crossorigin="anonymous" onerror="handleLogoError(this)">\\\
    : \\\<h1 class="modal-title">\</h1>\\\;

  let dynamicPlayLabel = 'Play';
  if (window._watchProgress) {
    const prog = window._watchProgress.find(p => p.file_id === playFileId);
    if (prog && prog.position_seconds > 0) {
      dynamicPlayLabel = 'Resume';
    }
  }

  container.innerHTML = \\\
    <div class="modal-header">
      <button class="btn-close" onclick="closeModal()">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>
    </div>
    <div class="modal-hero" style="background-image: url('\');">
      <div class="modal-hero-gradient"></div>
      <div class="modal-hero-content">
        \
        <div class="modal-actions">
           <button class="btn-premium-play" onclick="playVideo({fileId: '\', title: '\', poster: '\', _useStoredParts: \})">
             <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
             \
           </button>\;
code = code.replace(regex, replacement);
fs.writeFileSync('public/js/app.js', code);
