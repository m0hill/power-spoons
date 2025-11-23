# Quick Start Guide

Get up and running with Power Spoons in 2 minutes!

## Installation

### Step 1: Install Hammerspoon

If you don't already have Hammerspoon:

**Option A - Download:**
- Go to [hammerspoon.org](https://www.hammerspoon.org/)
- Download and install

**Option B - Homebrew:**
```bash
brew install --cask hammerspoon
```

### Step 2: Copy Power Spoons Code

1. **Open** (or create) the file: `~/.hammerspoon/init.lua`
   
   You can do this in Terminal:
   ```bash
   open -a TextEdit ~/.hammerspoon/init.lua
   ```

2. **Copy** the entire contents of the [init.lua](init.lua) file from this repository

3. **Paste** it into your `~/.hammerspoon/init.lua`

> **Already using Hammerspoon?** No problem! Just paste the Power Spoons code at the **end** of your existing `init.lua`. It won't interfere with your current setup.

### Step 3: Reload Hammerspoon

Press `Cmd+Ctrl+R` or click the Hammerspoon icon → "Reload Config"

### Step 4: You're Done!

Look for the **⚡ icon** in your menubar. Click it to install packages!

**What just happened?**
- The manager fetched the package list from GitHub
- You can now install packages with one click
- Packages will be downloaded and cached locally when you install them

---

## Installing Your First Package

Let's install **Whisper Transcription** as an example:

1. **Click** the ⚡ icon in your menubar
2. **Find** "Whisper Transcription" under "Available"
3. **Click** "+ Whisper Transcription"
4. **Click** "Install & Enable"
5. **Set your API key**:
   - Click ⚡ → "Secrets / API Keys"
   - Click "Groq API Key" → "Set / Update…"
   - Paste your API key (get one from [console.groq.com/keys](https://console.groq.com/keys))
   - Click "Save"
6. **Install sox** (required for audio recording):
   ```bash
   brew install sox
   ```
7. **Try it**: Hold `Option+/` to record, release to transcribe!

---

## Getting API Keys

### Groq API (for Whisper Transcription)

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up/login (free account)
3. Navigate to [API Keys](https://console.groq.com/keys)
4. Click "Create API Key"
5. Copy the key
6. Set it via ⚡ → Secrets / API Keys → Groq API Key → Set / Update…

**Cost**: $0.04 per hour of audio (very affordable!)

### Gemini API (for OCR)

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with Google account
3. Click "Create API Key"
4. Select your Google Cloud project (or create new)
5. Copy the key
6. Set it via ⚡ → Secrets / API Keys → Gemini API Key → Set / Update…

**Cost**: Free tier is very generous!

---

## Package Quick Reference

### Whisper Transcription
- **Hotkey**: `Option+/` (hold to record, release to transcribe)
- **Requires**: sox (`brew install sox`), Groq API key
- **Use case**: Dictate text instead of typing

### Gemini OCR
- **Hotkey**: `Cmd+Shift+S` (capture screenshot area)
- **Requires**: Gemini API key
- **Use case**: Extract text from images/screenshots

### Spotify Lyrics
- **Hotkey**: None (auto-starts)
- **Requires**: Spotify app
- **Use case**: See synced lyrics while listening
- **Tip**: Drag the overlay to move it, toggle via package menu

### Trimmy
- **Hotkey**: None (watches clipboard)
- **Requires**: Nothing!
- **Use case**: Flatten multi-line shell commands automatically
- **Settings**: Auto-trim on/off, aggressiveness levels

---

## Managing Packages

Everything is done from the **⚡ menubar icon**:

**To install a package:**
- Click ⚡ → "+ Package Name" → "Install & Enable"

**To disable/enable:**
- Click ⚡ → Package name → "Disable" or "Enable"

**To uninstall:**
- Click ⚡ → Package name → "Uninstall…"

**To configure settings:**
- Click ⚡ → Package name → (package-specific options)

---

## Troubleshooting

### "Whisper says sox is not installed"
```bash
brew install sox
```
Then reload Hammerspoon.

### "Missing API key"
- Click ⚡ → Secrets / API Keys
- Set the required key
- Try again

### "Package isn't working"
1. Check if it's enabled (should say "enabled" next to name)
2. Check Hammerspoon console for errors (menubar → Console)
3. Try disabling and re-enabling

### "Menubar icon disappeared"
- Press `Cmd+Ctrl+R` to reload
- Check Hammerspoon console for errors

### "I want to remove everything"
- Delete the Power Spoons code from your `init.lua`
- Reload Hammerspoon
- (Optional) Clear settings in Hammerspoon console:
  ```lua
  hs.settings.set("powerspoons.state", nil)
  ```

---

## For Advanced Users

### Where is everything stored?

- **Code**: In your `~/.hammerspoon/init.lua` (the file you pasted)
- **Settings**: Via `hs.settings` under key `powerspoons.state`
  - Includes: installed packages, enabled state, API keys
- **Lyrics position**: `powerspoons.lyrics.overlay.frame`
- **Trimmy settings**: `powerspoons.trimmy.*`

### How do I customize a package?

Edit the package code directly in your `init.lua`:

1. Find the package function (search for "createWhisperPackage", etc.)
2. Modify the `CONFIG` table at the top
3. Save and reload Hammerspoon

Example - change Whisper hotkey from `Option+/` to `Cmd+R`:
```lua
local CONFIG = {
    -- ... other settings ...
    HOTKEY_MODS = { "cmd" },  -- was: { "alt" }
    HOTKEY_KEY = "r",         -- was: "/"
}
```

### How do I add a new package?

1. Create a package function (see existing packages as examples)
2. Add it to the `PACKAGES_DEF` array
3. Reload Hammerspoon
4. It appears in "Available" packages

See [README.md#development](README.md#development) for detailed instructions.

---

## Next Steps

1. **Install all packages** you want to try
2. **Set API keys** for Whisper and/or Gemini
3. **Try them out** and customize hotkeys to your liking
4. **Star the repo** if you find it useful! ⭐

---

**Need help?** [Open an issue](https://github.com/m0hill/power-spoons/issues)

**Want to contribute?** Check out the [README](README.md)
