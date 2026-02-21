const express = require('express');
const { Api } = require('telegram');
const bigInt = require('big-integer');
const telegramService = require('../services/telegramService');
const { getTelegramChunk } = require('../services/chunkCacheService');

const router = express.Router();

function getAlignedLimit(offset) {
  return 1048576; // 1MB chunks globally
}

function alignOffset(offset) {
  return offset - (offset % 1048576); // Snap to 1MB barrier
}

function parseRangeHeader(rangeHeader, totalSize) {
  const match = /^bytes=(\d+)-(\d*)$/i.exec(String(rangeHeader || '').trim());
  if (!match) return null;

  const start = parseInt(match[1], 10);
  const end = match[2] ? parseInt(match[2], 10) : totalSize - 1;

  if (!Number.isFinite(start) || !Number.isFinite(end)) return null;
  if (start < 0 || end < 0 || start > end || start >= totalSize) return null;

  return {
    start,
    end: Math.min(end, totalSize - 1),
  };
}

function isLoopbackAddress(address) {
  const normalized = String(address || '').toLowerCase();
  return (
    normalized === '127.0.0.1' ||
    normalized === '::1' ||
    normalized === '::ffff:127.0.0.1' ||
    normalized === 'localhost'
  );
}

function createTelegramRangeStream(fileInfo, start, end) {
  const { Readable } = require('stream');
  const telegramClient = telegramService.getClient();
  if (!telegramClient) {
    throw new Error('Telegram client not ready');
  }

  let currentPosition = start;
  let bytesRemaining = end - start + 1;
  let destroyed = false;

  return new Readable({
    async read() {
      if (destroyed) return;
      if (bytesRemaining <= 0) {
        this.push(null);
        return;
      }

      try {
        const alignedOffset = alignOffset(currentPosition);
        const skipBytes = currentPosition - alignedOffset;
        const limit = getAlignedLimit(alignedOffset);

        let data = await getTelegramChunk(telegramClient, fileInfo, alignedOffset, limit);

        if (destroyed) return;
        if (!data || data.length === 0) {
          this.push(null);
          return;
        }

        if (skipBytes > 0) {
          data = data.slice(skipBytes);
        }
        if (data.length > bytesRemaining) {
          data = data.slice(0, bytesRemaining);
        }
        if (data.length === 0) {
          this.push(null);
          return;
        }

        currentPosition += data.length;
        bytesRemaining -= data.length;
        this.push(data);
      } catch (error) {
        this.destroy(error);
      }
    },

    destroy(err, cb) {
      destroyed = true;
      if (cb) cb(err);
    },
  });
}

router.get('/raw/:fileId', async (req, res) => {
  let telegramStream;

  try {
    if (!isLoopbackAddress(req.socket?.remoteAddress)) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { fileId } = req.params;
    const fileInfo = await telegramService.getFileInfo(fileId);

    if (!fileInfo) {
      return res.status(404).json({ error: 'File not found' });
    }

    const totalSize = Number(fileInfo.fileSize);
    if (!Number.isFinite(totalSize) || totalSize <= 0) {
      return res.status(404).json({ error: 'File not found' });
    }

    const rangeHeader = req.headers.range;
    let start = 0;
    let end = totalSize - 1;
    let statusCode = 200;

    if (rangeHeader) {
      const parsed = parseRangeHeader(rangeHeader, totalSize);
      if (!parsed) {
        return res.status(416)
          .set('Content-Range', `bytes */${totalSize}`)
          .end();
      }

      start = parsed.start;
      end = parsed.end;
      statusCode = 206;
    }

    const contentLength = end - start + 1;
    const headers = {
      'Accept-Ranges': 'bytes',
      'Content-Length': contentLength,
      'Content-Type': 'application/octet-stream',
      'Cache-Control': 'no-cache',
    };

    if (statusCode === 206) {
      headers['Content-Range'] = `bytes ${start}-${end}/${totalSize}`;
    }

    res.writeHead(statusCode, headers);

    telegramStream = createTelegramRangeStream(fileInfo, start, end);

    req.on('close', () => {
      if (telegramStream && !telegramStream.destroyed) {
        telegramStream.destroy();
      }
    });

    telegramStream.on('error', (error) => {
      console.error(`[InternalRaw] Stream error for ${fileId}:`, error.message);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Stream failed' });
      } else if (!res.writableEnded) {
        res.end();
      }
    });

    telegramStream.pipe(res);
  } catch (error) {
    console.error('[InternalRaw] Route error:', error.message);
    if (telegramStream && !telegramStream.destroyed) {
      telegramStream.destroy();
    }
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal raw stream failed' });
    } else if (!res.writableEnded) {
      res.end();
    }
  }
});

module.exports = router;
