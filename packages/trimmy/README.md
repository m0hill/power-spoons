# Trimmy

Automatically flattens multi-line shell commands in your clipboard.

## Overview

Have you ever copied a multi-line shell command from documentation and had it fail because of line breaks? Trimmy automatically detects command-line text in your clipboard and flattens it into a single line, making it safe to paste into your terminal.

## Features

- **Automatic detection**: Watches clipboard for multi-line commands
- **Smart flattening**: Intelligently removes line breaks and backslashes
- **Configurable aggressiveness**: Low, normal, or high detection sensitivity
- **Preserve blank lines**: Optional mode to keep paragraph breaks
- **Manual control**: Enable/disable auto-trim on the fly
- **Zero interference**: Only processes text that looks like shell commands

## Setup

Enable the package in the Trimmy submenu. It starts working immediately.

## Usage

### Automatic Mode (Default)

1. Copy multi-line command text from anywhere
2. Trimmy automatically detects and flattens it
3. Paste normally into your terminal

### Example

**Before (copied text):**
```
docker run -d \
  --name myapp \
  -p 8080:8080 \
  myimage:latest
```

**After (clipboard automatically updated):**
```
docker run -d --name myapp -p 8080:8080 myimage:latest
```

### Manual Trim

If auto-trim is disabled, use the menu option:
1. Copy text to clipboard
2. Go to **Trimmy → Trim Clipboard Now**
3. Paste the flattened result

## Configuration

Adjust settings from the Trimmy menu:

### Aggressiveness
- **Low**: Only processes very obvious shell commands (score ≥ 3)
- **Normal**: Processes typical command-line patterns (score ≥ 2)
- **High**: Processes anything that might be a command (score ≥ 1)

### Preserve Blank Lines
- **On**: Keeps blank lines between command groups
- **Off**: Removes all blank lines

### Auto-Trim
- **On**: Automatically processes clipboard (default)
- **Off**: Only trim when manually triggered

## How It Works

Trimmy analyzes clipboard text for command-line indicators:
1. Lines with backslash continuations (`\`)
2. Common CLI patterns (sudo, apt, brew, docker, etc.)
3. Flag-style arguments (`--flag`, `-f`)
4. Environment variable patterns (`ENV=value`)
5. All-caps variable patterns (`VAR=value`)

Each indicator increases a "score". If the score meets the aggressiveness threshold, Trimmy flattens the text.

## What Gets Flattened

- Backslash line continuations: `\ \n` → ` `
- Line breaks in commands: `command \n --flag` → `command --flag`
- All-caps environment variables: `VAR=value \n command` → `VAR=value command`

## What Doesn't Get Flattened

- Regular prose (low command-line score)
- Code in other languages (JavaScript, Python, etc.)
- Markdown or formatted documents
- Text with low command-line indicators

## Menu Options

- **Enable/Disable Auto-Trim**: Toggle automatic processing
- **Trim Clipboard Now**: Manually flatten current clipboard
- **Aggressiveness**: Adjust detection sensitivity
- **Preserve Blank Lines**: Toggle blank line preservation

## Troubleshooting

**Text not being flattened:**
- Check if auto-trim is enabled
- Try increasing aggressiveness to "High"
- Manually trigger: "Trim Clipboard Now"

**Wrong text getting flattened:**
- Decrease aggressiveness to "Low"
- Disable auto-trim and use manual mode
- Check for command-like patterns in your text

**Blank lines removed unwanted:**
- Enable "Preserve Blank Lines" option

## Technical Details

- Polls clipboard every 0.15 seconds using `hs.pasteboard.changeCount()`
- Scores text based on command-line patterns
- Applies flattening rules based on aggressiveness setting
- Preserves undo history by updating the actual clipboard
- Settings persist across Hammerspoon restarts
