importScripts('/js/gramjs-worker-bundle.js');

const { TelegramClient, StringSession, Api, PromisedWebSockets, ConnectionTCPObfuscated, Buffer } = self.GramJSWorker;

let client = null;
let isConnected = false;

// Store info about registered files
const files = new Map(); // fileId -> { fileSize, mimeType, dcId, fileLocation }

// Chunk Cache (LRU) - same as server-side
const CHUNK_SIZE = 1048576; // 1MB chunks
const MAX_CACHE_ENTRIES = 150; // ~150MB
const chunkCache = new Map(); // key: "fileId_alignedOffset", value: ArrayBuffer

function getCacheKey(fileId, offset) {
  return `${fileId}_${offset}`;
}

function addToCache(key, buffer) {
  if (chunkCache.has(key)) {
    chunkCache.delete(key);
  } else if (chunkCache.size >= MAX_CACHE_ENTRIES) {
    // Evict oldest (first item in Map)
    const firstKey = chunkCache.keys().next().value;
    chunkCache.delete(firstKey);
  }
  chunkCache.set(key, buffer);
}

// Recreate the Api.InputDocumentFileLocation from the serialized object
function deserializeLocation(locStr) {
  if (!locStr) return null;
  // Convert from string to BigInt
  const id = locStr.id ? BigInt(locStr.id) : undefined;
  const accessHash = locStr.accessHash ? BigInt(locStr.accessHash) : undefined;
  
  // Convert base64 fileReference to a real Buffer using the polyfill
  let fileReference;
  if (locStr.fileReference) {
    fileReference = Buffer.from(locStr.fileReference, 'base64');
  } else {
    fileReference = Buffer.alloc(0);
  }
  
  return new Api.InputDocumentFileLocation({
    id,
    accessHash,
    fileReference,
    thumbSize: locStr.thumbSize || ''
  });
}

// Parse BigInt correctly when importing from gramjs
const bigInt = (val) => BigInt(val);

self.addEventListener('message', async (event) => {
  const data = event.data;
  
  if (data.type === 'INIT') {
    try {
      const { sessionString, apiId, apiHash } = data;
      const stringSession = new StringSession(sessionString);
      
      // Override the raw IP in the session string with the Web WebSocket proxy domain
      const dcId = stringSession.dcId;
      const webDcDomains = {
        1: "pluto.web.telegram.org",
        2: "venus.web.telegram.org",
        3: "aurora.web.telegram.org",
        4: "vesta.web.telegram.org",
        5: "flora.web.telegram.org"
      };
      
      if (webDcDomains[dcId]) {
        stringSession.setDC(dcId, webDcDomains[dcId], 443);
      }
      
      client = new TelegramClient(stringSession, apiId, apiHash, {
        connectionRetries: 5,
        useWSS: true,
        connection: ConnectionTCPObfuscated,
        networkSocket: PromisedWebSockets,
        autoReconnect: true
      });
      
      // Disable the update loop cleanly by tricking GramJS into thinking it already started.
      // This prevents the `.unref` crash and avoids fetching unnecessary updates.
      client._loopStarted = true;
      
      await client.connect();
      isConnected = true;
      console.log('[TelegramWorker] Connected to Telegram MTProto');
      
      self.postMessage({ type: 'INIT_OK' });
    } catch (error) {
      console.error('[TelegramWorker] Init Error:', error);
      self.postMessage({ type: 'INIT_ERROR', error: error.message });
    }
  } 
  else if (data.type === 'REGISTER_FILE') {
    files.set(data.fileId, {
      fileSize: data.fileSize,
      mimeType: data.mimeType,
      dcId: data.dcId,
      location: deserializeLocation(data.fileLocation)
    });
  }
  else if (data.type === 'INIT_PORT') {
    // The main thread sends us a port to communicate directly with the Service Worker
    const swPort = event.ports[0];
    
    swPort.onmessage = async (e) => {
      if (e.data.type === 'FETCH_RANGE') {
        // e.ports[0] is the specific response port for this single request
        const resPort = e.ports[0];
        await handleFetchRange(e.data.fileId, e.data.start, e.data.end, resPort);
      }
    };
  }
});

async function handleFetchRange(fileId, requestedStart, requestedEnd, port) {
  try {
    if (!client || !isConnected) {
      throw new Error('Telegram client not initialized or connected');
    }

    const fileInfo = files.get(fileId);
    if (!fileInfo) {
      throw new Error(`File ${fileId} not registered with worker`);
    }

    const fileSize = fileInfo.fileSize;
    let end = requestedEnd !== -1 ? requestedEnd : fileSize - 1;
    if (end >= fileSize) end = fileSize - 1;
    
    // We fetch in 1MB aligned chunks
    const alignedStart = requestedStart - (requestedStart % CHUNK_SIZE);
    
    // We'll just fetch one chunk to satisfy the request. If the request spans multiple chunks,
    // the browser will just make another request when it needs more.
    // However, if the requested range is small, we slice it out of the 1MB chunk.
    const chunkKey = getCacheKey(fileId, alignedStart);
    let chunkBuffer = chunkCache.get(chunkKey);
    
    if (!chunkBuffer) {
      // Fetch from Telegram
      let retries = 3;
      let lastError;
      
      while (retries > 0) {
        try {
          chunkBuffer = await fetchTelegramChunk(fileInfo.location, fileInfo.dcId, alignedStart, CHUNK_SIZE);
          addToCache(chunkKey, chunkBuffer);
          break;
        } catch (error) {
          lastError = error;
          
          if (error.errorMessage === 'AUTH_KEY_UNREGISTERED') {
            throw error; // Fatal
          }
          
          if (error.errorMessage && error.errorMessage.includes('FLOOD_WAIT_')) {
            const seconds = parseInt(error.errorMessage.split('_')[2]) || 1;
            console.log(`[TelegramWorker] Flood wait for ${seconds}s`);
            await new Promise(r => setTimeout(r, seconds * 1000));
            continue; // Don't decrement retries for flood wait
          }
          
          retries--;
          if (retries > 0) {
            await new Promise(r => setTimeout(r, 500)); // basic backoff
          }
        }
      }
      
      if (!chunkBuffer) {
        throw lastError || new Error('Failed to fetch chunk after retries');
      }
    }
    
    // Calculate how much of the chunk to return based on the requested start
    // The requestedStart could be in the middle of the 1MB chunk
    const offsetInChunk = requestedStart - alignedStart;
    
    // The browser usually requests large ranges, but we can only return what we have in this chunk.
    // If the chunk doesn't cover the full requested range, we just return what we have (206 Partial Content supports this).
    const bytesAvailable = chunkBuffer.byteLength - offsetInChunk;
    const bytesToReturn = Math.min(bytesAvailable, end - requestedStart + 1);
    
    const sliceBuffer = chunkBuffer.slice(offsetInChunk, offsetInChunk + bytesToReturn);
    
    const resEnd = requestedStart + sliceBuffer.byteLength - 1;
    
    port.postMessage({
      data: sliceBuffer,
      start: requestedStart,
      end: resEnd,
      totalSize: fileSize,
      mimeType: fileInfo.mimeType
    }, [sliceBuffer]); // Transfer the array buffer
    
  } catch (error) {
    console.error('[TelegramWorker] Error fetching range:', error);
    port.postMessage({ error: error.message });
  }
}

// Helper to fetch exactly one chunk from MTProto
async function fetchTelegramChunk(location, dcId, offset, limit) {
  let sender = await client.getSender(dcId);
  
  console.log(`[TelegramWorker] Sanity Check - Buffer.isBuffer(fileReference):`, Buffer.isBuffer(location.fileReference));
  
  if (!sender) {
    // If we don't have a sender for this DC, we might need to create one
    // But GramJS usually handles this if we just use the default client
    // For now, try default client.invoke
    const req = new Api.upload.GetFile({
      location: location,
      offset: bigInt(offset),
      limit: limit,
      precise: false
    });
    
    const result = await client.invoke(req);
    // Convert Buffer to ArrayBuffer for web worker
    return result.bytes.buffer.slice(result.bytes.byteOffset, result.bytes.byteOffset + result.bytes.byteLength);
  }
  
  const req = new Api.upload.GetFile({
    location: location,
    offset: bigInt(offset),
    limit: limit,
    precise: false
  });

  const result = await client.invokeWithSender(req, sender);
  return result.bytes.buffer.slice(result.bytes.byteOffset, result.bytes.byteOffset + result.bytes.byteLength);
}
