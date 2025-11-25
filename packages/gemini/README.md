# Gemini OCR

Extract and translate text from screenshots using Google's Gemini AI.

## Overview

Take a screenshot of any region on your screen and instantly extract the text using OCR (Optical Character Recognition). Gemini automatically translates non-English text and formats the output cleanly.

## Features

- **Interactive screenshot capture**: Select any region of your screen
- **AI-powered OCR**: Uses Google's Gemini Flash model for accurate text extraction
- **Auto-translation**: Translates non-English text to English
- **Smart formatting**: Organizes extracted text with proper spacing and structure
- **Auto-paste**: Extracted text is automatically typed at your cursor
- **Visual & audio feedback**: Notifications and sounds for each step

## Setup

### 1. Get API Key

1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click **Create API Key**
4. Copy the generated key
5. In Power Spoons menu, go to **Gemini OCR → Gemini API Key → Set / Update…**
6. Paste your API key

### 2. Enable the Package

Click **Enable** in the Gemini OCR submenu.

## Usage

1. Place your cursor where you want the extracted text to appear
2. Press `Cmd+Shift+S`
3. Click and drag to select the area containing text
4. Wait for OCR processing (usually 2-5 seconds)
5. Extracted text will be automatically typed at your cursor

## What It Does

The OCR process:
1. Captures the selected screen region as PNG
2. Encodes the image as base64
3. Sends it to Gemini with OCR instructions
4. Extracts text from code blocks in the response
5. Types the cleaned text at your cursor

## Configuration

Modify these settings in the source code if needed:

- `HOTKEY_MODS`: Hotkey modifiers (default: `{ "cmd", "shift" }`)
- `HOTKEY_KEY`: Hotkey key (default: `"s"`)
- `MODEL`: Gemini model (default: `gemini-flash-lite-latest`)
- `MIME_TYPE`: Image format (default: `image/png`)
- `SCREENSHOT_TIMEOUT`: Max time to wait for screenshot (default: 60 seconds)
- `ENABLE_NOTIFY`: Show notifications (default: true)
- `ENABLE_SOUND`: Play sounds (default: true)

## Use Cases

- Extract text from images, PDFs, or scanned documents
- Copy text from videos or streaming content
- Translate foreign language text in screenshots
- Extract code from tutorial videos or images
- Capture text from non-selectable UI elements

## Troubleshooting

**Screenshot not capturing:**
- Grant screen recording permissions to Hammerspoon in System Settings → Privacy & Security → Screen Recording
- Try pressing the hotkey again
- Check console for errors

**No text extracted:**
- Ensure the screenshot contains readable text
- Try capturing a smaller, clearer region
- Check API key is set correctly

**API errors:**
- Verify your API key is valid
- Check your internet connection
- Ensure you haven't exceeded API quota

## Technical Details

- Uses macOS native `screencapture` utility
- Encodes images as base64 for API transmission
- Uses Gemini's vision capabilities for text extraction
- Extracts code blocks from Gemini's markdown response
- Simulates keyboard input for pasting
