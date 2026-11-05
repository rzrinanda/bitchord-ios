const http = require('http');
const https = require('https');
const url = require('url');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';
const CACHE_DIR = path.join(__dirname, '.cache');

if (!fs.existsSync(CACHE_DIR)) {
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
  } catch (err) {
    console.error('Failed to create cache dir:', err.message);
  }
}

// In-memory stream URL and metadata cache (TTL: 6 hours)
const memoryCache = new Map();
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;

function getCached(key) {
  const item = memoryCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiresAt) {
    memoryCache.delete(key);
    return null;
  }
  return item.value;
}

function setCached(key, value, ttlMs = CACHE_TTL_MS) {
  memoryCache.set(key, {
    value,
    expiresAt: Date.now() + ttlMs
  });
}

const IOS_UA = 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
const ANDROID_UA = 'com.google.android.youtube/20.10.35 (Linux; U; Android 14; en_US; Pixel 8 Pro)';

/**
 * Resolves best audio streams from YouTube Innertube API
 */
async function resolveAudioStream(videoId) {
  const cached = getCached(`stream:${videoId}`);
  if (cached) {
    return cached;
  }

  // Client 1: iOS Innertube
  const iosPayload = JSON.stringify({
    context: {
      client: {
        clientName: 'IOS',
        clientVersion: '20.10.4',
        deviceMake: 'Apple',
        deviceModel: 'iPhone16,2',
        osName: 'iPhone',
        osVersion: '18.3.2.22D82',
        hl: 'id',
        gl: 'ID'
      }
    },
    videoId
  });

  const iosResult = await requestInnertubePlayer(iosPayload, IOS_UA);
  if (iosResult && iosResult.formats && iosResult.formats.length > 0) {
    setCached(`stream:${videoId}`, iosResult);
    return iosResult;
  }

  // Client 2: Android Innertube Fallback
  const androidPayload = JSON.stringify({
    context: {
      client: {
        clientName: 'ANDROID',
        clientVersion: '20.10.35',
        deviceMake: 'Google',
        deviceModel: 'Pixel 8 Pro',
        osName: 'Android',
        osVersion: '14',
        hl: 'id',
        gl: 'ID'
      }
    },
    videoId
  });

  const androidResult = await requestInnertubePlayer(androidPayload, ANDROID_UA);
  if (androidResult && androidResult.formats && androidResult.formats.length > 0) {
    setCached(`stream:${videoId}`, androidResult);
    return androidResult;
  }

  throw new Error('No playable audio stream available for videoId ' + videoId);
}

function requestInnertubePlayer(payload, userAgent) {
  return new Promise((resolve) => {
    const req = https.request('https://www.youtube.com/youtubei/v1/player', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': userAgent,
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com'
      },
      timeout: 5000
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const data = JSON.parse(body);
          const playability = data.playabilityStatus?.status;
          if (playability && playability !== 'OK' && playability !== 'LIVE_STREAM_OFFLINE') {
            console.warn(`[BitChord Server] Innertube playability: ${playability} - ${data.playabilityStatus?.reason}`);
          }

          const rawFormats = data.streamingData?.adaptiveFormats || [];
          const audioFormats = rawFormats
            .filter(f => f.mimeType && (f.mimeType.startsWith('audio/mp4') || f.mimeType.startsWith('audio/webm') || f.mimeType.startsWith('audio/m4a')))
            .map(f => {
              const isAAC = f.mimeType.includes('mp4a') || f.mimeType.includes('mp4');
              return {
                itag: f.itag,
                url: f.url,
                mimeType: f.mimeType,
                codec: isAAC ? 'aac' : (f.mimeType.includes('opus') ? 'opus' : 'audio'),
                format: isAAC ? 'audio/mp4' : 'audio/webm',
                bitrate: Math.round((f.bitrate || 128000) / 1000),
                contentLength: parseInt(f.contentLength || '0', 10),
                sampleRate: parseInt(f.audioSampleRate || '44100', 10),
                isLossless: false
              };
            })
            .filter(f => !!f.url)
            .sort((a, b) => {
              // Prioritize iOS native audio/mp4 (AAC) over WebM/Opus for seamless AVPlayer playback
              if (a.format !== b.format) {
                return a.format === 'audio/mp4' ? -1 : 1;
              }
              return b.bitrate - a.bitrate;
            });

          const title = data.videoDetails?.title || 'Unknown Title';
          const author = data.videoDetails?.author || 'Unknown Artist';
          const duration = parseInt(data.videoDetails?.lengthSeconds || '0', 10);

          resolve({
            videoId: data.videoDetails?.videoId,
            title,
            author,
            duration,
            formats: audioFormats
          });
        } catch (err) {
          resolve(null);
        }
      });
    });

    req.on('error', () => resolve(null));
    req.on('timeout', () => {
      req.destroy();
      resolve(null);
    });
    req.write(payload);
    req.end();
  });
}

/**
 * Searches tracks via YouTube Music API
 */
async function searchTracks(query) {
  const cached = getCached(`search:${query}`);
  if (cached) return cached;

  const payload = JSON.stringify({
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20250101.01.00',
        hl: 'id',
        gl: 'ID'
      }
    },
    query,
    params: 'EgWKAQIIAWoKEAkQChAFEAMQBA=='
  });

  return new Promise((resolve) => {
    const req = https.request('https://music.youtube.com/youtubei/v1/search', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0.0.0 Safari/537.36',
        'Origin': 'https://music.youtube.com'
      },
      timeout: 5000
    }, res => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => {
        try {
          const data = JSON.parse(body);
          const sections = data.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];
          const results = [];

          for (const section of sections) {
            const items = section.musicShelfRenderer?.contents || [];
            for (const item of items) {
              const flex = item.musicResponsiveListItemRenderer;
              if (!flex) continue;

              const titleCol = flex.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.title?.runs?.[0]?.text;
              const subCols = flex.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.title?.runs || [];
              const artistText = subCols.map(r => r.text).join('');
              const videoId = flex.playlistItemData?.videoId;
              const thumbnails = flex.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails || [];
              const bestThumbnail = thumbnails[thumbnails.length - 1]?.url;

              if (videoId && titleCol) {
                results.push({
                  id: videoId,
                  title: titleCol,
                  artist: artistText,
                  artworkURL: bestThumbnail,
                  streamURL: `http://localhost:${PORT}/stream/${videoId}`
                });
              }
            }
          }

          setCached(`search:${query}`, results, 30 * 60 * 1000);
          resolve(results);
        } catch (e) {
          resolve([]);
        }
      });
    });

    req.on('error', () => resolve([]));
    req.on('timeout', () => {
      req.destroy();
      resolve([]);
    });
    req.write(payload);
    req.end();
  });
}

/**
 * Proxies media stream to client with Range header support and authentic headers
 */
function proxyMediaStream(streamUrl, req, res) {
  const headers = {
    'User-Agent': IOS_UA,
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com'
  };

  if (req.headers.range) {
    headers['Range'] = req.headers.range;
  }

  const parsedUrl = new URL(streamUrl);
  const proxyReq = https.request(parsedUrl, {
    method: req.method === 'HEAD' ? 'HEAD' : 'GET',
    headers,
    timeout: 15000
  }, proxyRes => {
    const responseHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Accept-Ranges': 'bytes'
    };

    const passHeaders = ['content-type', 'content-length', 'content-range', 'last-modified', 'etag'];
    for (const h of passHeaders) {
      if (proxyRes.headers[h]) {
        responseHeaders[h] = proxyRes.headers[h];
      }
    }

    res.writeHead(proxyRes.statusCode || 200, responseHeaders);

    if (req.method === 'HEAD') {
      res.end();
      proxyRes.destroy();
      return;
    }

    proxyRes.pipe(res);

    proxyRes.on('error', (err) => {
      console.error('[BitChord Server] Proxy stream error:', err.message);
      if (!res.headersSent) {
        res.writeHead(502);
      }
      res.end();
    });
  });

  proxyReq.on('error', (err) => {
    console.error('[BitChord Server] Upstream request error:', err.message);
    if (!res.headersSent) {
      res.writeHead(502, { 'Access-Control-Allow-Origin': '*' });
      res.end('Upstream media fetch failed');
    }
  });

  proxyReq.on('timeout', () => {
    proxyReq.destroy();
    if (!res.headersSent) {
      res.writeHead(504, { 'Access-Control-Allow-Origin': '*' });
      res.end('Upstream gateway timeout');
    }
  });

  req.on('close', () => {
    proxyReq.destroy();
  });

  proxyReq.end();
}

// HTTP Server
const server = http.createServer(async (req, res) => {
  const parsed = url.parse(req.url, true);
  const pathname = parsed.pathname;

  // Global CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // 1. Health check
  if (pathname === '/health' || pathname === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      service: 'BitChord Official Streaming Backend',
      version: '1.0.0',
      uptimeSeconds: Math.round(process.uptime()),
      cachedItems: memoryCache.size
    }));
    return;
  }

  // 2. Addon manifest for BitChord Addon System
  if (pathname === '/manifest.json') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      id: 'bitchord-official-backend',
      name: 'BitChord High-Speed Backend',
      version: '1.0.0',
      description: 'Ultra-fast direct audio streaming, deciphering, and caching proxy for BitChord',
      resources: ['stream', 'search'],
      types: ['music', 'track'],
      allowDownloads: true,
      catalogs: []
    }));
    return;
  }

  // 3. Search endpoint: /api/search?q=... or /search?q=...
  if (pathname === '/api/search' || pathname === '/search') {
    const q = parsed.query.q || parsed.query.query;
    if (!q) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Missing query parameter "q"' }));
      return;
    }
    const results = await searchTracks(q);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ results }));
    return;
  }

  // 4. Track Info endpoint: /api/info/:id or /info/:id
  const infoMatch = pathname.match(/^\/(?:api\/)?info\/([A-Za-z0-9_-]{11})$/);
  if (infoMatch) {
    const videoId = infoMatch[1];
    try {
      const data = await resolveAudioStream(videoId);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(data));
    } catch (e) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  // 5. Direct Stream endpoint: /api/stream/:id or /stream/:id or /stream?id=...
  let streamVideoId = null;
  const streamMatch = pathname.match(/^\/(?:api\/)?stream\/([A-Za-z0-9_-]{11})$/);
  if (streamMatch) {
    streamVideoId = streamMatch[1];
  } else if (pathname === '/stream' || pathname === '/api/stream') {
    if (parsed.query.id && parsed.query.id.length === 11) {
      streamVideoId = parsed.query.id;
    } else if (parsed.query.url) {
      // Direct proxy forwarding mode
      proxyMediaStream(parsed.query.url, req, res);
      return;
    }
  }

  if (streamVideoId) {
    try {
      const streamInfo = await resolveAudioStream(streamVideoId);
      const chosenFormat = streamInfo.formats.find(f => f.format === 'audio/mp4') || streamInfo.formats[0];

      if (!chosenFormat || !chosenFormat.url) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'No stream available' }));
        return;
      }

      // If client requested JSON metadata (?format=json)
      if (parsed.query.format === 'json') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          streamURL: `http://${req.headers.host || `localhost:${PORT}`}/stream/${streamVideoId}`,
          directURL: chosenFormat.url,
          format: chosenFormat.format,
          codec: chosenFormat.codec,
          bitrate: chosenFormat.bitrate,
          isLossless: false,
          sampleRate: chosenFormat.sampleRate,
          sourceId: 'bitchord_backend'
        }));
        return;
      }

      // Otherwise pipe the audio stream directly!
      proxyMediaStream(chosenFormat.url, req, res);
    } catch (err) {
      console.error(`[BitChord Server] Stream resolution error for ${streamVideoId}:`, err.message);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  // Fallback 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Route not found' }));
});

server.listen(PORT, HOST, () => {
  console.log(`[BitChord Server] Streaming backend running at http://${HOST}:${PORT}`);
  console.log(`[BitChord Server] Health endpoint: http://${HOST}:${PORT}/health`);
  console.log(`[BitChord Server] Manifest: http://${HOST}:${PORT}/manifest.json`);
});
