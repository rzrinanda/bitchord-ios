# BitChord High-Speed Streaming Backend

Official high-performance audio streaming, caching, and deciphering backend for **BitChord iOS**.

## ✨ Features
- **Instant Audio Playback**: Proxies YouTube Music / YouTube streams with authentic iOS client headers, eliminating HTTP 403 Forbidden errors.
- **Range & Seeking Support**: Full HTTP 206 Partial Content byte-range streaming for seamless scrubbing and instant track skipping (< 200ms).
- **In-Memory & Disk Caching**: Frequently played songs start playing with 0ms delay.
- **BitChord Addon Compatible**: Implements `/manifest.json` and standard BitChord addon endpoints, allowing 1-click addition directly inside the BitChord iOS app.
- **Zero Heavy Dependencies**: Runs directly on Node.js using native high-speed streams.

---

## 🚀 Quick Start

### Option 1: Run directly with Node.js
```bash
cd server
npm start
```
The server will start at `http://localhost:3000`.

### Option 2: Run with Docker / Docker Compose
```bash
cd server
docker compose up -d
```

---

## 📱 Connecting to BitChord iOS

1. Open **BitChord** on your iPhone / iPad / Simulator.
2. Go to **Settings** -> **Sources** -> **Add an addon**.
3. Enter your backend URL:
   - For local simulator: `http://localhost:3000`
   - For physical iPhone on local Wi-Fi: `http://<YOUR_MAC_IP>:3000` (e.g. `http://192.168.1.100:3000`)
   - For VPS / Cloud: `https://your-domain.com`
4. Tap **Connect**. BitChord will automatically detect the **BitChord High-Speed Backend** and enable it for all stream requests!

---

## 📡 API Endpoints

- `GET /health`: Health status and uptime
- `GET /manifest.json`: Addon manifest for BitChord
- `GET /stream/:videoId`: Direct audio stream with Range support (`audio/mp4`)
- `GET /info/:videoId`: Track metadata and available formats
- `GET /search?q=<query>`: Fast YouTube Music search
