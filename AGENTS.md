# Agent Guidelines for Power Spoons

## Project Structure
```
power-spoons/
├── init.lua              # Main package manager
├── manifest.json         # Package registry with metadata
├── README.md             # User-facing documentation
├── AGENTS.md             # This file - for AI agents/contributors
└── packages/             # Individual packages
    ├── whisper/
    │   ├── init.lua      # Package entry point
    │   └── README.md     # Package docs
    ├── gemini/
    ├── lyrics/
```

**User Runtime Structure:**
When installed, creates `~/.hammerspoon/powerspoons/`:
```
powerspoons/
├── state.json            # Package installation state, manifest
├── secrets.json          # API keys (gitignored)
├── settings/             # Per-package settings
│   ├── lyrics.json
│   └── ...
└── cache/                # Downloaded package code
    ├── whisper.lua
    └── ...
```

**Package Structure Convention:**
- Each package is a folder in `packages/`
- `init.lua` is the entry point (returns a factory function)
- `README.md` contains full documentation
- Complex packages can have multiple files alongside `init.lua`
- Manifest points to `packages/{package}/init.lua` as the source

## Build/Test/Lint Commands
- **Reload config**: Open Hammerspoon console and click "Reload Config" or run `hs.reload()`
- **Test script**: `hs /Users/mohil/.hammerspoon/init.lua` (or specific module file)
- **No formal tests**: This is a config-based project; test manually via Hammerspoon console

## Code Style

### Language & Structure
- Language: Lua 5.3+ (Hammerspoon's embedded runtime)
- **Packages** are folders in `packages/` directory
- Each package has `init.lua` as its entry point
- Each package has `README.md` for documentation
- Packages return a factory function that takes `manager` parameter
- Factory returns a table with `start()`, `stop()`, and optionally `getMenuItems()` and `getHotkeySpec()` functions
- Package pattern: `return function(manager) ... end`

### Docstrings (Optional)
Packages can include docstrings at the top of init.lua for documentation:
```lua
--- Package Name
--- Brief description of what the package does.
---
--- @package packageid
--- @version 1.0.0
--- @author yourname
```

### Variables & Naming
- `SCREAMING_SNAKE_CASE` for constants and config tables (e.g., `CONFIG`, `MODELS`, `LANGUAGES`)
- `camelCase` for local functions (e.g., `createIndicator`, `updateMenuBar`, `formatTime`)
- `snake_case` for module-level state variables (e.g., `currentTrackId`, `pollTimer`, `menubar`)
- Prefix private settings keys with module name (e.g., `"lyrics.overlay.frame"`, `"whisper.aggressiveness"`)

### Imports & Dependencies
- Packages are loaded dynamically from GitHub via manifest
- Access Hammerspoon APIs via `hs.*` namespace (e.g., `hs.hotkey`, `hs.notify`, `hs.canvas`)
- Use `manager.getSecret(key)` to retrieve API keys from the manager
- Complex packages can `require()` additional files in their folder (relative paths)

### Error Handling
- Use `pcall()` for JSON parsing: `local ok, result = pcall(hs.json.decode, data)`
- Check dependencies at init time (e.g., check for `sox` binary and API keys)
- Validate state before operations (e.g., check if file exists with `hs.fs.attributes()`)
- Gracefully handle missing data with fallback messages in UI

### Secrets Management
- API keys stored in `~/.hammerspoon/powerspoons/secrets.json`
- Packages declare required secrets in `manifest.json`
- Access secrets via `manager.getSecret("KEY_NAME")`
- Never hardcode API keys in source files
- Users set secrets via GUI in the menubar menu

### Settings Management
- Each package gets its own settings file: `~/.hammerspoon/powerspoons/settings/{packageId}.json`
- Access via manager API:
  ```lua
  manager.getSetting(packageId, "key", defaultValue)
  manager.setSetting(packageId, "key", value)
  ```
- All settings are JSON - transparent and editable
- Settings persist across restarts automatically

### Menubar Integration
- Packages can expose menu items via `getMenuItems()` function
- Menu items are plain tables: `{ title = "...", fn = function() ... end }`
- Returned menu items are inserted into the package's submenu automatically
- Manager handles all menubar rendering and updates
- Packages should call menu refresh after state changes (handled by manager wrapper)

### Hotkeys (Configurable)
Packages can expose configurable hotkeys using the Spoons-compatible `getHotkeySpec()` convention:

```lua
-- Default hotkey (used if user hasn't customized)
local DEFAULT_HOTKEY = { { "cmd", "shift" }, "s" }

function P.getHotkeySpec()
    return {
        capture = {
            fn = startCapture,  -- Simple: single function
            description = "Start Capture",
        },
        record = {
            fn = { press = startRecording, release = stopRecording },  -- Hold-style
            description = "Hold to Record",
        },
    }
end

function P.start()
    -- Get configured or default hotkey
    local hotkeyDef = manager.getHotkey(PACKAGE_ID, "capture", DEFAULT_HOTKEY)
    if hotkeyDef then
        local spec = P.getHotkeySpec()
        boundHotkeys = manager.bindHotkeysToSpec(PACKAGE_ID, spec, { capture = hotkeyDef })
    end
end
```

In `manifest.json`, declare hotkeys for UI configuration:
```json
{
    "hotkeys": [
        {
            "action": "capture",
            "description": "Start Capture",
            "default": "Cmd+Shift+S"
        }
    ]
}
```

Users can customize hotkeys via the menubar UI. The manager stores custom hotkeys in `settings/{packageId}.json` under the `hotkeys` key.

---

## Creating a New Package

### Step 1: Create Package Structure

```bash
mkdir packages/mypackage
touch packages/mypackage/init.lua
touch packages/mypackage/README.md
```

### Step 2: Write Package Code

**`packages/mypackage/init.lua`:**
```lua
--- My Package
--- Does something cool with configurable hotkeys.
---
--- @package mypackage
--- @version 1.0.0
--- @author yourname

return function(manager)
	local P = {}
	local PACKAGE_ID = "mypackage"
	
	-- Default hotkey (can be overridden via manager.getHotkey)
	local DEFAULT_HOTKEY = { { "cmd", "shift" }, "m" }
	
	-- Package state
	local myState = nil
	local boundHotkeys = {}
	
	-- Load settings
	local myConfig = manager.getSetting(PACKAGE_ID, "config", "default")
	
	local function doAction()
		-- Do something
		manager.setSetting(PACKAGE_ID, "lastUsed", os.time())
		hs.notify.new({title="My Package", informativeText="Action triggered!"}):send()
	end
	
	--- Returns hotkey specification for this package.
	--- Used by the manager for hotkey configuration UI.
	--- @return table Hotkey spec with action names mapped to functions
	function P.getHotkeySpec()
		return {
			action = {
				fn = doAction,
				description = "Do Action",
			},
		}
	end
	
	function P.start()
		-- Initialize your package
		hs.notify.new({title="My Package", informativeText="Started!"}):send()
		
		-- Get configured or default hotkey
		local hotkeyDef = manager.getHotkey(PACKAGE_ID, "action", DEFAULT_HOTKEY)
		if hotkeyDef then
			local spec = P.getHotkeySpec()
			boundHotkeys = manager.bindHotkeysToSpec(PACKAGE_ID, spec, { action = hotkeyDef })
		end
	end
	
	function P.stop()
		-- Clean up resources
		for _, hk in pairs(boundHotkeys) do
			if hk then hk:delete() end
		end
		boundHotkeys = {}
	end
	
	function P.getMenuItems()
		return {
			{
				title = "Do Action Now",
				fn = function()
					doAction()
				end
			}
		}
	end
	
	return P
end
```

### Step 3: Add to Manifest

**`manifest.json`:**
```json
{
  "packages": [
    {
      "id": "mypackage",
      "name": "My Package",
      "version": "1.0.0",
      "description": "Does something cool",
      "source": "https://raw.githubusercontent.com/m0hill/power-spoons/main/packages/mypackage/init.lua",
      "readme": "https://github.com/m0hill/power-spoons/blob/main/packages/mypackage/README.md",
      "hotkeys": [
        {
          "action": "action",
          "description": "Do Action",
          "default": "Cmd+Shift+M"
        }
      ],
      "secrets": [
        {
          "key": "MY_API_KEY",
          "label": "My API Key",
          "hint": "Get your key from https://example.com/api"
        }
      ]
    }
  ]
}
```

### Step 4: Document Your Package

**`packages/mypackage/README.md`:**
```markdown
# My Package

Does something cool.

## Setup

1. Install via Power Spoons menubar
2. Set your API key if needed
3. Use hotkey Cmd+Shift+M

## Settings

- `config` - Main configuration option (default: "default")
- `lastUsed` - Timestamp of last usage

Settings stored in `~/.hammerspoon/powerspoons/settings/mypackage.json`
```

### Step 5: Test

1. Copy `init.lua` to your `~/.hammerspoon/init.lua`
2. Reload Hammerspoon
3. Click ⚡ menubar icon
4. Your package appears in "Available"
5. Install and test

### Step 6: Commit

```bash
git add packages/mypackage/
git add manifest.json
git commit -m "Add mypackage"
git push
```

Users will see your package after clicking "Refresh package list"!

## Manager API Reference

### Secrets
```lua
manager.getSecret(key)                    -- Get API key
manager.setSecret(key, value)             -- Set API key (usually via GUI)
```

### Settings
```lua
manager.getSetting(packageId, key, default)     -- Get setting with default
manager.setSetting(packageId, key, value)       -- Set setting
manager.getSettings(packageId)                  -- Get all settings as table
manager.setSettings(packageId, table)           -- Set all settings
```

### Hotkeys
```lua
manager.getHotkey(packageId, action, default)   -- Get configured hotkey with fallback
manager.setHotkey(packageId, action, hotkeyDef) -- Set hotkey (nil to clear)
manager.parseHotkeyString("Cmd+Shift+S")        -- Parse string to {{mods}, key}
manager.formatHotkeyString({{"cmd", "shift"}, "s"}) -- Format to string
manager.bindHotkeysToSpec(packageId, spec, mapping) -- Bind hotkeys from spec
```

## Package Lifecycle

1. **Installation:** User clicks "Install" → Code downloaded to cache → State updated
2. **Start:** Code loaded from cache → Factory function executed → `start()` called
3. **Stop:** `stop()` called → Instance removed from runtime
4. **Uninstall:** `stop()` called → Cache file deleted → State updated

## Persistence

- **Package code:** `~/.hammerspoon/powerspoons/cache/{packageId}.lua`
- **Secrets:** `~/.hammerspoon/powerspoons/secrets.json`
- **Settings:** `~/.hammerspoon/powerspoons/settings/{packageId}.json`
- **Installation state:** `~/.hammerspoon/powerspoons/state.json`

All files are JSON (except cached Lua code) - fully transparent and editable.
