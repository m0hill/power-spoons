# Power Spoons

> A remote package manager for Hammerspoon productivity tools

Power Spoons is a Hammerspoon Spoon that installs and manages productivity packages from a central manifest, with settings stored as plain JSON.

Built on [Hammerspoon](https://www.hammerspoon.org/). Licensed under [MIT](https://opensource.org/licenses/MIT).

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

## Installation

### Quick Start

**Step 1**: Install Hammerspoon

Download from [hammerspoon.org](https://www.hammerspoon.org/).

**Step 2**: Install the Spoon

Download the latest release and double-click `PowerSpoons.spoon` to install it.

**Step 3**: Load it from your `~/.hammerspoon/init.lua`

```lua
hs.loadSpoon("PowerSpoons")
spoon.PowerSpoons:start()
```

**Step 4**: Reload Hammerspoon

Press `Cmd+Ctrl+R` or click "Reload Config" in the Hammerspoon console.

**Step 5**: Install packages

Click the Power Spoons icon in your menubar → Install packages → Set API keys → Done!

---

## Usage

### Managing Packages

Everything is done from the Power Spoons menubar icon:

**Installing a package:**
1. Click the Power Spoons icon
2. Click "+ Package Name" under "Available"
3. Click "Install & Enable"
4. Package is now running!

**Enabling/Disabling:**
- Click package name under "Installed"
- Click "Enable" or "Disable"

**Setting API Keys:**
1. Click the Power Spoons icon
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

---

## API Keys

### Groq API (for Whisper)
1. Sign up at [console.groq.com](https://console.groq.com)
2. Navigate to [API Keys](https://console.groq.com/keys)
3. Create a new API key
4. Set it via the Power Spoons menu → Secrets / API Keys → Groq API Key → Set / Update…

**Pricing**: Whisper Large v3 Turbo is $0.04/hour of audio (very affordable!)

### Gemini API (for OCR)
1. Get a key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Set it via the Power Spoons menu → Secrets / API Keys → Gemini API Key → Set / Update…

**Pricing**: Gemini Flash Lite has a generous free tier

---

## How It Works

Power Spoons uses a **remote package system** that's simple and secure:

1. **You install once**: Add the Spoon to `~/.hammerspoon/Spoons/PowerSpoons.spoon`
2. **Bootstrap fetches the manager**: The manager code is downloaded from GitHub on first run
3. **Manager fetches packages**: When you install a package, it's downloaded from GitHub
4. **Auto-updates**: The package list refreshes automatically (every 24 hours) or manually via "Refresh" button
5. **Local caching**: Downloaded packages (including the manager) are cached in `~/.hammerspoon/powerspoons/cache/`
6. **Safe execution**: Package code is loaded in a sandbox and can only access the manager API

**What gets stored where:**
- **Bootstrap code**: In `~/.hammerspoon/Spoons/PowerSpoons.spoon/`
- **Manager code**: Cached in `~/.hammerspoon/powerspoons/cache/manager.lua`
- **Package list**: Fetched from `manifest.json` on GitHub, cached locally
- **Package code**: Downloaded from GitHub when installed, cached locally
- **Your settings**: Installed packages, enabled state, API keys → stored as JSON files

**Security:**
- ✅ Bootstrap code is visible and isolated (Spoon)
- ✅ Manager and packages are fetched from the official repo only
- ✅ API keys stored in `~/.hammerspoon/powerspoons/secrets.json`
- ✅ All code runs in Hammerspoon's Lua sandbox

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
4. **Local cache**: Downloaded packages are saved to `~/.hammerspoon/powerspoons/cache/`
5. **Persistent state**: Your settings survive updates

### Customizing Packages

**Edit a cached package:**
1. Navigate to: `~/.hammerspoon/powerspoons/cache/`
2. Edit the package file (e.g., `whisper.lua`)
3. Modify the `CONFIG` table at the top
4. Reload Hammerspoon

**Note**: Changes to cached files will be lost if you uninstall and reinstall the package.

**Use a custom manifest** (for your own forks):
1. Fork the Power Spoons repository
2. Modify packages in your fork
3. Update your Spoon config in `~/.hammerspoon/init.lua`:
   ```lua
   hs.loadSpoon("PowerSpoons")
   spoon.PowerSpoons:setConfig({
     manifestUrl = "https://raw.githubusercontent.com/YOUR_USERNAME/power-spoons/main/manifest.json",
   }):start()
   ```
4. Reload Hammerspoon → packages will be fetched from your fork

### Where Everything Lives

```
~/.hammerspoon/
├── init.lua                          # Your config (loads the Power Spoons Spoon)
├── Spoons/
│   └── PowerSpoons.spoon/            # Power Spoons bootstrap
└── powerspoons/                      # Runtime state and caches
    ├── state.json
    ├── secrets.json
    ├── settings/
    └── cache/
        └── manager.lua
```

Settings and secrets are stored as JSON files under `~/.hammerspoon/powerspoons/`.

---

## Troubleshooting

**"Whisper says sox is not installed"**
- Run: `brew install sox`
- Reload Hammerspoon config

**"No API key set"**
- Click the Power Spoons menu → Secrets / API Keys
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
- Remove `PowerSpoons.spoon` from `~/.hammerspoon/Spoons/`
- Remove the load/start lines from `~/.hammerspoon/init.lua`
- Reload Hammerspoon
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

- **Hammerspoon** - [www.hammerspoon.org](https://www.hammerspoon.org/)
- **lrclib.net** - Free lyrics API

---

## Issues & Support

- Found a bug? [Open an issue](https://github.com/m0hill/power-spoons/issues)
- Feature request? [Start a discussion](https://github.com/m0hill/power-spoons/discussions)
- Documentation unclear? PRs welcome!

---

**Made with ❤️ for the Hammerspoon community**
