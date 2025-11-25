# Power Spoons

> A simple, secure package manager for Hammerspoon productivity tools

Replace bloated Electron apps with lightweight, native macOS automation using Lua scripts. Power Spoons brings you professional-grade productivity tools that integrate seamlessly with macOS through a single menubar icon.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Why Power Spoons?

**Before Power Spoons:**
- Complicated installation scripts
- Multiple shell commands
- Scattered configuration files
- Manual API key management
- Security risks with external installers

**With Power Spoons:**
- **One copy-paste**: Single snippet to get started
- **One icon**: All packages managed from one menubar icon
- **Visual management**: Install/uninstall with clicks, not commands
- **Transparent**: All config stored in readable JSON files
- **Works everywhere**: New users and existing Hammerspoon users alike

---

## Available Packages

### Whisper Transcription
Real-time speech-to-text using OpenAI's Whisper via Groq API.

- **Hotkey**: `Option+/` - Hold to record, release to transcribe
- **Auto-paste**: Transcribed text inserted automatically
- **Fast**: Uses Groq's optimized Whisper API
- **Requires**: sox (`brew install sox`), Groq API key

---

### Gemini OCR
Screenshot-based text extraction with Google's Gemini AI.

- **Hotkey**: `Cmd+Shift+S` - Screenshot area with text
- **AI-powered**: Gemini Flash for accurate OCR
- **Auto-translate**: Non-English text to English
- **Smart formatting**: Clean, organized output
- **Requires**: Gemini API key

---

### Spotify Lyrics
Floating synchronized lyrics overlay for Spotify.

- **Auto-sync**: Real-time lyrics synchronized with playback
- **Draggable**: Position overlay anywhere on screen
- **Persistent**: Remembers position and visibility
- **No dependencies**: Works out of the box with Spotify

---

### Trimmy
Automatically flatten multi-line shell commands in clipboard.

- **Auto-detect**: Recognizes shell commands automatically
- **Smart parsing**: Handles backslashes, pipes, flags
- **Configurable**: Low/Normal/High aggressiveness levels
- **Manual override**: Force-trim via menubar
- **No dependencies**: Pure Hammerspoon implementation

---

## Installation

### Quick Start (Works for Everyone)

**Step 1**: Install Hammerspoon

If you don't have Hammerspoon installed:
- Download from [hammerspoon.org](https://www.hammerspoon.org/)
- Or: `brew install --cask hammerspoon`

**Step 2**: Copy the Power Spoons code

1. Open this file: `~/.hammerspoon/init.lua` (create it if it doesn't exist)
2. Copy the entire contents of [init.lua](init.lua) from this repository
3. Paste it into your `~/.hammerspoon/init.lua`

> **Note for existing Hammerspoon users**: Just paste the Power Spoons code at the end of your existing `init.lua`. It won't interfere with your current setup.

**Step 3**: Reload Hammerspoon

Press `Cmd+Ctrl+R` or click "Reload Config" in the Hammerspoon console.

**Step 4**: Install packages

Click the ⚡ icon in your menubar → Install packages → Set API keys → Done!

---

## Usage

### Managing Packages

Everything is done from the **⚡ menubar icon**:

**Installing a package:**
1. Click ⚡ icon
2. Click "+ Package Name" under "Available"
3. Click "Install & Enable"
4. Package is now running!

**Enabling/Disabling:**
- Click package name under "Installed"
- Click "Enable" or "Disable"

**Setting API Keys:**
1. Click ⚡ icon
2. Click on an installed package
3. Find "API Keys / Secrets" section
4. Click "Set / Update…" for the key you need
5. Paste your API key and click "Save"

**Uninstalling:**
- Click package name → "Uninstall…"

### Configuration Files

All settings stored in `~/.hammerspoon/powerspoons/`:

```
powerspoons/
├── state.json          # Package installation state
├── secrets.json        # API keys (gitignore this!)
├── settings/           # Per-package settings
│   ├── lyrics.json
│   ├── trimmy.json
│   └── ...
└── cache/              # Downloaded package code
```

**All files are JSON** - you can view and edit them directly! Perfect for version control and portability.

### Package-Specific Settings

Each package has its own settings accessible from its submenu:

**Whisper:**
- Status indicator shows "Ready", "Recording…", or "Transcribing…"
- Hold `Option+/` to record, release to transcribe

**Gemini OCR:**
- Press `Cmd+Shift+S` to capture a screenshot area
- Wait for processing (you'll see a notification)
- Extracted text is automatically copied to clipboard

**Spotify Lyrics:**
- Starts automatically when installed
- Toggle "Hide Overlay" / "Show Overlay" from package menu
- Drag the overlay to reposition it (position is saved)

**Trimmy:**
- "Auto-Trim" toggle enables/disables automatic clipboard monitoring
- "Trim Clipboard Now" forces a trim operation
- Adjust "Aggressiveness" (Low/Normal/High)
- Toggle "Keep blank lines" to preserve blank lines when trimming

---

## API Keys

### Groq API (for Whisper)
1. Sign up at [console.groq.com](https://console.groq.com)
2. Navigate to [API Keys](https://console.groq.com/keys)
3. Create a new API key
4. Set it via ⚡ → Secrets / API Keys → Groq API Key → Set / Update…

**Pricing**: Whisper Large v3 Turbo is $0.04/hour of audio (very affordable!)

### Gemini API (for OCR)
1. Get a key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Set it via ⚡ → Secrets / API Keys → Gemini API Key → Set / Update…

**Pricing**: Gemini Flash Lite has a generous free tier

---

## How It Works

Power Spoons uses a **remote package system** that's simple and secure:

1. **You copy once**: Paste the manager code into `~/.hammerspoon/init.lua`
2. **Manager fetches packages**: When you install a package, it's downloaded from GitHub
3. **Auto-updates**: The package list refreshes automatically (every 24 hours) or manually via "Refresh" button
4. **Local caching**: Downloaded packages are cached in `~/.hammerspoon/powerspoons_cache/`
5. **Safe execution**: Package code is loaded in a sandbox and can only access the manager API

**What gets stored where:**
- **Manager code**: In your `init.lua` (you paste this once)
- **Package list**: Fetched from `manifest.json` on GitHub, cached locally
- **Package code**: Downloaded from GitHub when installed, cached locally
- **Your settings**: Installed packages, enabled state, API keys → stored via `hs.settings`

**Security:**
- ✅ Manager code is minimal and visible (you paste it)
- ✅ Package code is fetched from the official repo only
- ✅ API keys stored via Hammerspoon's secure settings (not plain text files)
- ✅ All code runs in Hammerspoon's Lua sandbox

---

## For Existing Hammerspoon Users

**Power Spoons is designed to coexist** with your existing configuration:

- **Paste at the end**: Just add the Power Spoons code after your existing config
- **Namespace**: All settings are prefixed with `powerspoons.*`
- **No conflicts**: Doesn't touch your existing hotkeys, menubar items, or timers
- **Optional**: You can mix Power Spoons packages with your own scripts

Example existing `init.lua`:

```lua
-- Your existing config
hs.hotkey.bind({"cmd"}, "space", function()
    hs.application.launchOrFocus("Terminal")
end)

-- ... other stuff ...

----------------------------------------------------------------------
-- Power Spoons (paste the entire Power Spoons code here)
----------------------------------------------------------------------
local PowerSpoons = (function()
    -- ... (Power Spoons code)
end)()

PowerSpoons.init()
```

---

## Development

### Adding a New Package

Want to add a new package? It's easy!

**1. Create your package file** (`packages/mypackage.lua`):

```lua
-- My Package
-- Version: 1.0.0
-- Description: What it does

return function(manager)
    local P = {}
    
    -- Called when package is enabled
    function P.start()
        -- Set up hotkeys, timers, watchers, etc.
        
        -- Get API keys from manager
        local apiKey = manager.getSecret("MY_API_KEY")
    end
    
    -- Called when package is disabled or Hammerspoon reloads
    function P.stop()
        -- Clean up resources
    end
    
    -- Optional: show status in menu
    function P.getStatus()
        return "Ready"
    end
    
    return P
end
```

**2. Add to `manifest.json`**:

```json
{
  "id": "mypackage",
  "name": "My Package",
  "description": "What it does",
  "version": "1.0.0",
  "author": "yourusername",
  "defaultEnabled": false,
  "hotkey": "Cmd+Shift+X",
  "source": "https://raw.githubusercontent.com/m0hill/power-spoons/main/packages/mypackage.lua",
  "secrets": [
    {
      "key": "MY_API_KEY",
      "label": "My Service API Key",
      "hint": "Get from https://example.com/keys"
    }
  ],
  "dependencies": {}
}
```

**3. Commit and push** to GitHub

**4. Users refresh** their package list → your package appears!

That's it! No need to update `init.lua`. Users will see your package automatically when they click "Refresh package list".

### Code Style

See [AGENTS.md](AGENTS.md) for detailed guidelines:
- `CONFIG` tables for constants
- `camelCase` for local functions
- `snake_case` for state variables
- Always clean up resources in `stop()`

---

## Remote Package System

### How It Works

1. **Manifest**: `manifest.json` on GitHub lists all available packages
2. **Auto-refresh**: Manager checks for new packages every 24 hours
3. **On-demand download**: Packages are downloaded only when you install them
4. **Local cache**: Downloaded packages are saved to `~/.hammerspoon/powerspoons_cache/`
5. **Persistent state**: Your settings survive updates

### Customizing Packages

**Edit a cached package:**
1. Navigate to: `~/.hammerspoon/powerspoons_cache/`
2. Edit the package file (e.g., `whisper.lua`)
3. Modify the `CONFIG` table at the top
4. Reload Hammerspoon

**Note**: Changes to cached files will be lost if you uninstall and reinstall the package.

**Use a custom manifest** (for your own forks):
1. Fork the Power Spoons repository
2. Modify packages in your fork
3. Update `MANIFEST_URL` in `init.lua` to point to your fork:
   ```lua
   local MANIFEST_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/power-spoons/main/manifest.json"
   ```
4. Reload Hammerspoon → packages will be fetched from your fork

### Where Everything Lives

```
~/.hammerspoon/
├── init.lua                          # Your config (contains Power Spoons manager)
└── powerspoons_cache/                # Downloaded packages
    ├── whisper.lua
    ├── gemini.lua
    ├── lyrics.lua
    └── trimmy.lua
```

Settings are stored via `hs.settings` under the key `powerspoons.state` (not in files).

---

## Troubleshooting

**"Whisper says sox is not installed"**
- Run: `brew install sox`
- Reload Hammerspoon config

**"No API key set"**
- Click ⚡ → Secrets / API Keys
- Set the required key
- Try again

**"Package isn't working"**
- Check if it's enabled (should say "enabled" next to package name)
- Look in Hammerspoon console for errors (⌘+⌥+H to open)
- Try disabling and re-enabling the package

**"Menubar icon disappeared"**
- Reload Hammerspoon config (⌘+⌥+R)
- Check Hammerspoon console for errors

**"I want to completely remove Power Spoons"**
- Delete the Power Spoons code from your `init.lua`
- Reload config
- (Optional) Delete config directory: `rm -rf ~/.hammerspoon/powerspoons`

---

## For Contributors

Want to add a new package? See [AGENTS.md](AGENTS.md) for the complete development guide.

Quick overview:
1. Create `packages/yourpackage/init.lua` (returns factory function)
2. Add entry to `manifest.json`
3. Test locally, then push
4. Users see it after "Refresh package list"

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Credits

- **Trimmy** spoon inspired by [@steipete](https://github.com/steipete)'s [native Trimmy app](https://github.com/steipete/Trimmy)
- **Hammerspoon** - [www.hammerspoon.org](https://www.hammerspoon.org/)
- **Groq** - Lightning-fast Whisper API
- **Google Gemini** - Powerful multimodal AI
- **lrclib.net** - Free lyrics API

---

## Issues & Support

- Found a bug? [Open an issue](https://github.com/m0hill/power-spoons/issues)
- Feature request? [Start a discussion](https://github.com/m0hill/power-spoons/discussions)
- Documentation unclear? PRs welcome!

---

**Made with ❤️ for the Hammerspoon community**
