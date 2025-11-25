# Agent Guidelines for Power Spoons

## Project Structure
```
power-spoons/
├── init.lua              # Main package manager (copy-paste into user's ~/.hammerspoon/)
├── manifest.json         # Package registry with metadata
└── packages/             # Individual packages (each is a folder)
    ├── whisper/
    │   ├── init.lua      # Main package code
    │   └── README.md     # Package documentation
    ├── gemini/
    │   ├── init.lua
    │   └── README.md
    ├── lyrics/
    │   ├── init.lua
    │   └── README.md
    └── trimmy/
        ├── init.lua
        └── README.md
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
- Factory returns a table with `start()`, `stop()`, and optionally `getMenuItems()` functions
- Package pattern: `return function(manager) ... end`

### Variables & Naming
- `SCREAMING_SNAKE_CASE` for constants and config tables (e.g., `CONFIG`, `MODELS`, `LANGUAGES`)
- `camelCase` for local functions (e.g., `createIndicator`, `updateMenuBar`, `formatTime`)
- `snake_case` for module-level state variables (e.g., `currentTrackId`, `pollTimer`, `menubar`)
- Prefix private settings keys with module name (e.g., `"lyrics.overlay.frame"`, `"trimmy.aggressiveness"`)

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
- API keys are stored via Power Spoons manager (Hammerspoon settings)
- Packages declare required secrets in `manifest.json`
- Access secrets via `manager.getSecret("KEY_NAME")`
- Never hardcode API keys in source files
- Users set secrets via GUI in the menubar menu

### Menubar Integration
- Packages can expose menu items via `getMenuItems()` function
- Menu items are plain tables: `{ title = "...", fn = function() ... end }`
- Returned menu items are inserted into the package's submenu automatically
- Manager handles all menubar rendering and updates
- Packages should call menu refresh after state changes (handled by manager wrapper)
