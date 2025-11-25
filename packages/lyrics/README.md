# Spotify Lyrics

Floating, synchronized lyrics overlay for Spotify.

## Overview

A beautiful, draggable lyrics overlay that automatically syncs with whatever you're playing on Spotify. Shows time-synced lyrics with smooth scrolling and customizable appearance.

## Features

- **Auto-sync**: Automatically detects what's playing on Spotify
- **Time-synchronized**: Lyrics highlight in real-time with the music
- **Draggable overlay**: Move the lyrics window anywhere on screen
- **Persistent position**: Remembers overlay position and visibility
- **Smooth scrolling**: Lyrics smoothly scroll as the song plays
- **Click-through mode**: Optional pass-through mode for working while viewing
- **Manual refresh**: Re-fetch lyrics if needed

## Setup

### 1. Install Spotify

Make sure the Spotify desktop app is installed and running.

### 2. Enable the Package

Click **Enable** in the Spotify Lyrics submenu.

## Usage

The lyrics overlay appears automatically when:
- Spotify is playing
- Lyrics are available for the current track
- The overlay visibility is enabled

### Controls

**From the menu:**
- **Show/Hide Lyrics**: Toggle overlay visibility
- **Refresh Lyrics**: Re-fetch lyrics for the current track

**From the overlay:**
- **Drag**: Click and drag anywhere on the overlay to move it
- **Close**: Click the × button to hide

## How It Works

1. Polls Spotify every 0.5 seconds to detect current track
2. Fetches synchronized lyrics from [lrclib.net](https://lrclib.net)
3. Parses LRC format (time-stamped lyrics)
4. Displays overlay with current and next 4 lines
5. Highlights current line and updates as song plays

## Lyrics Format

The package uses the LRC (lyrics) format with timestamps:
```
[00:12.00]First line of lyrics
[00:15.50]Second line of lyrics
```

## Configuration

The overlay is customizable via the source code:

- `POLL_INTERVAL`: How often to check Spotify (default: 0.5 seconds)
- Overlay colors, fonts, and sizes
- Number of lyrics lines shown (default: 5)
- Opacity and background blur

## Limitations

- **Lyrics availability**: Not all songs have synchronized lyrics in the lrclib.net database
- **Spotify desktop only**: Requires the Spotify desktop app (not web player)
- **English-centric**: Database primarily contains English lyrics

## Troubleshooting

**Overlay not appearing:**
- Make sure Spotify desktop app is running
- Try playing a popular song (more likely to have lyrics)
- Check if "Show Lyrics" is enabled in the menu
- Click "Refresh Lyrics" to re-fetch

**Lyrics out of sync:**
- This is a limitation of the lyrics database
- Click "Refresh Lyrics" to reload
- Report timing issues to lrclib.net

**Can't click through overlay:**
- The overlay captures clicks by default
- Modify the canvas settings in source if you want click-through

## Technical Details

- Uses AppleScript to query Spotify state
- Fetches lyrics via HTTP from lrclib.net API
- Parses LRC format timestamps
- Renders overlay using `hs.canvas`
- Stores position/visibility in Hammerspoon settings
- Updates display every 0.5 seconds during playback
