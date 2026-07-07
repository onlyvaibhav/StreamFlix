// StreamFlix Service Worker
// Intercepts range requests for /vstream/:fileId and delegates them to the Telegram Web Worker.

const workerCache = new Map(); // Keep track of the dedicated worker port if established
let telegramWorkerPort = null;

// The SW installs and activates immediately
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

// Setup MessageChannel listener to receive the port from the frontend
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'INIT_PORT') {
    telegramWorkerPort = event.ports[0];
    console.log('[ServiceWorker] Received port to Telegram Dedicated Worker');
  }
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // We only intercept /vstream/ requests
  if (url.pathname.startsWith('/vstream/')) {
    event.respondWith(handleStreamRequest(event.request));
  }
});

async function handleStreamRequest(request) {
  if (!telegramWorkerPort) {
    return new Response('Telegram Worker not initialized', { status: 503 });
  }

  const url = new URL(request.url);
  const fileId = url.pathname.replace('/vstream/', '');
  
  // Parse Range header
  const rangeHeader = request.headers.get('Range');
  let start = 0;
  let end = -1;

  if (rangeHeader) {
    const match = rangeHeader.match(/bytes=(\d+)-(\d*)/);
    if (match) {
      start = parseInt(match[1], 10);
      if (match[2]) {
        end = parseInt(match[2], 10);
      }
    }
  }

  return new Promise((resolve) => {
    // We create a unique MessageChannel for this specific request
    const channel = new MessageChannel();
    
    // Timeout for safety (30 seconds)
    const timeoutId = setTimeout(() => {
      resolve(new Response('Gateway Timeout', { status: 504 }));
    }, 30000);

    channel.port1.onmessage = (event) => {
      clearTimeout(timeoutId);
      
      if (event.data.error) {
        console.error('[ServiceWorker] Error from Telegram Worker:', event.data.error);
        resolve(new Response('Internal Error: ' + event.data.error, { status: 500 }));
        return;
      }

      const { data, start: resStart, end: resEnd, totalSize, mimeType } = event.data;
      
      // Calculate content length
      const contentLength = resEnd - resStart + 1;

      // Construct 206 Partial Content response
      const headers = new Headers();
      headers.set('Content-Range', `bytes ${resStart}-${resEnd}/${totalSize}`);
      headers.set('Accept-Ranges', 'bytes');
      headers.set('Content-Length', contentLength.toString());
      headers.set('Content-Type', mimeType || 'video/mp4');

      resolve(new Response(data, {
        status: 206,
        statusText: 'Partial Content',
        headers
      }));
    };

    // Forward the request to the dedicated worker
    telegramWorkerPort.postMessage({
      type: 'FETCH_RANGE',
      fileId,
      start,
      end
    }, [channel.port2]);
  });
}
