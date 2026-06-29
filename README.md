<img src="VelqiBanner.jpg" width="1200" alt="Velqi — Free Music Streaming"/>

# Velqi

<div align="center">

[![Release](https://img.shields.io/github/v/release/lupyther/Velqi-Music-App?color=7C3AED&label=Latest%20Release&style=flat-square)](https://github.com/lupyther/Velqi-Music-App/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android-green?style=flat-square&logo=android)](https://github.com/lupyther/Velqi-Music-App/releases/latest)
[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=flat-square&logo=flutter)](https://flutter.dev)

[**Download**](#download) · [**Features**](#features) · [**Troubleshooting**](#troubleshooting)

</div>

---

## Overview

Velqi is a free, open-source music streaming app for Android. It streams audio directly from YouTube and YouTube Music using an embedded Python backend — no accounts, no ads, no tracking.

---

## Features

- **Ad-free streaming** — No interruptions, ever.
- **No login required** — Open the app and start listening immediately.
- **Smart caching** — Songs are cached while playing for smooth, uninterrupted playback.
- **Offline downloads** — Save tracks to your device and listen without internet.
- **Synced lyrics** — Animated, word-by-word synchronized lyrics (via LRCLIB) alongside plain text support.
- **Dynamic Material You theming** — UI accent colors adapt to the current track's album art.
- **Built-in equalizer** — Full hardware equalizer support.
- **Crossfade** — Smooth audio transitions between tracks (configurable duration).
- **Radio / Queue** — Auto-generated radio queues from any song, album, or artist.
- **Background playback** — Full notification controls and lock screen integration.
- **Flexible navigation** — Switch between Bottom Bar and Side Navigation Bar.
- **Sleep timer** — Stops playback after a set time.
- **Silence skipping** — Automatically skips silent gaps in tracks.
- **Playlist & library management** — Create playlists, bookmark artists and albums.
- **Import from YouTube** — Share a YouTube or YouTube Music link directly into Velqi.
- **Streaming quality control** — Choose your preferred audio bitrate.
- **YouTube cookies support** — Use your own cookies for regional or restricted content.

---

## Download

Choose the APK that matches your device architecture:

| Device Type | APK | Size |
|---|---|---|
| Modern phones (2018+) | `app-arm64-v8a-release.apk` | ~24 MB |
| Older phones | `app-armeabi-v7a-release.apk` | ~23 MB |
| Emulators (BlueStacks, etc.) | `app-x86_64-release.apk` | ~25 MB |

➡️ **[Download from Releases](https://github.com/lupyther/Velqi-Music-App/releases/latest)**

> If you're unsure which APK to pick, download `app-arm64-v8a-release.apk`.

---

## Architecture

Velqi uses a hybrid Flutter + Python architecture:

```
Flutter UI  ←—HTTP—→  Python microservice (localhost:8765)
                            ├── yt-dlp       → stream resolution
                            └── ytmusicapi   → search, browse, metadata
```

- The Python backend runs **embedded inside the app process** using `serious_python`, with no external server or dependencies required.
- All heavy networking and decryption is handled by the Python layer, keeping the Dart UI thread fast and responsive.
- On first launch, the backend initialises in the background while the splash screen is shown. Subsequent launches are near-instant.

---

## Troubleshooting

**Playback stops when screen turns off / after a few songs:**
- Go to **Settings → Battery Optimizations** and set Velqi to **Unrestricted**, or enable **Ignore Battery Optimizations** from within the app.

**App shows loading screen for a long time on first launch:**
- This is normal. The first launch initialises the embedded audio engine (~15–30 seconds depending on device speed). Subsequent launches start immediately.

**Content not loading / network errors:**
- Verify your internet connection.
- If YouTube content is region-restricted, try adding your YouTube cookies via **Settings → Advanced → YouTube Cookies**.

---

## License

```
Velqi is free software licensed under the GNU General Public License v3.0.

Conditions:
- Modified versions must remain free and open-source.
- Cannot be published on closed-source app stores (e.g., Google Play, App Store).
- Cannot be used for commercial or profitable purposes without explicit permission.
```

---

## Disclaimer

This project is developed for educational purposes. It is not affiliated with, sponsored by, or endorsed by YouTube, Google, or any other content provider. All media content accessed through this app belongs to its respective rights holders.

The software is provided "as-is", without warranty of any kind.
