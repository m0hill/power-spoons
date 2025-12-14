# Whisper Transcription

Voice-to-text transcription powered by Groq or OpenAI Whisper API.

## Overview

Hold a hotkey to record audio, then release to automatically transcribe and paste the text wherever your cursor is. Perfect for hands-free typing, dictating notes, or writing emails.

## Features

- **Hold-to-record**: Press and hold `Option+/` to start recording
- **Auto-paste**: Transcribed text is automatically typed at your cursor position
- **Fast processing**: Uses Groq's optimized Whisper model or OpenAI's Whisper for quick results
- **Provider choice**: Switch between Groq and OpenAI APIs
- **Audio feedback**: Plays sounds on start, stop, success, and error
- **Visual notifications**: Shows status updates during recording and processing

## Setup

### 1. Install Dependencies

```bash
brew install sox
```

The `sox` utility is required for audio recording.

### 2. Get API Key

Choose either Groq (faster, free tier) or OpenAI (more reliable):

**Option A: Groq (Recommended)**
1. Sign up at [Groq Console](https://console.groq.com/)
2. Navigate to [API Keys](https://console.groq.com/keys)
3. Create a new API key
4. In Power Spoons menu, go to **Whisper Transcription → Groq API Key → Set / Update…**
5. Paste your API key

**Option B: OpenAI**
1. Sign up at [OpenAI Platform](https://platform.openai.com/)
2. Navigate to [API Keys](https://platform.openai.com/api-keys)
3. Create a new API key
4. In Power Spoons menu, go to **Whisper Transcription → OpenAI API Key → Set / Update…**
5. Paste your API key

### 3. Enable the Package

Click **Enable** in the Whisper Transcription submenu.

## Usage

1. Place your cursor where you want text to appear
2. Press and hold `Option+/`
3. Speak clearly into your microphone
4. Release the key when done
5. Wait a moment for transcription
6. Text will be automatically typed

## Configuration

Use the Power Spoons menubar → Whisper Transcription submenu to configure:

- Show notifications
- Play sounds
- Provider (Groq or OpenAI)

For advanced tweaks, edit `packages/whisper/init.lua`:

- `GROQ_MODEL`: Groq Whisper model (default: `whisper-large-v3-turbo`)
- `OPENAI_MODEL`: OpenAI Whisper model (default: `whisper-1`)
- `DEFAULT_PROVIDER`: Default API provider (default: `groq`)
- `SAMPLE_RATE`: Audio quality (default: 16000 Hz)
- `MIN_BYTES`: Minimum recording size (default: 1000 bytes)
- `MAX_HOLD_SECONDS`: Maximum recording duration (default: 300 seconds)
- `API_TIMEOUT`: API request timeout (default: 90 seconds)
- `ENABLE_NOTIFY`: Show notifications (default: true)
- `ENABLE_SOUND`: Play sounds (default: true)

## Troubleshooting

**No audio recorded:**
- Check microphone permissions for Hammerspoon in System Settings → Privacy & Security → Microphone
- Ensure `sox` is installed: `which sox`

**API errors:**
- Verify your API key is set correctly
- Check your internet connection
- Ensure you have API credits remaining

**Text not pasting:**
- Make sure a text field is focused
- Try clicking in the text field before recording

## Technical Details

- Uses `sox` for high-quality audio recording at 16kHz mono
- Sends audio to Groq or OpenAI Whisper API endpoints
- Simulates keyboard input to paste transcribed text
- Cleans up temporary audio files automatically
- Supports switching between providers via menu
