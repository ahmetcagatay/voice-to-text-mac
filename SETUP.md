# Setup Instructions (for Claude Code)

Follow these steps in order. Run each command and verify it works before moving to the next.

## Step 1: Install dependencies

```bash
# Install Homebrew if not installed
which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Sox (audio recording) and Whisper.cpp (speech-to-text)
brew install sox whisper-cpp
```

## Step 2: Download the Whisper model

```bash
whisper-cpp-download-ggml-model medium
```

This downloads ~1.5GB. Only needed once.

## Step 3: Install Hammerspoon

Check if Hammerspoon is installed:

```bash
ls /Applications/Hammerspoon.app 2>/dev/null || echo "NOT INSTALLED"
```

If not installed:
```bash
brew install --cask hammerspoon
```

Then tell the user: "Open Hammerspoon from Applications, click 'Enable Accessibility' when prompted, then come back."

## Step 4: Create the Hammerspoon config

```bash
mkdir -p ~/.hammerspoon
```

Write the contents of `init.lua` from this repo to `~/.hammerspoon/init.lua`.

## Step 5: Create the watchdog (optional but recommended)

Write the contents of `watchdog.sh` from this repo to `~/.hammerspoon/watchdog.sh` and run:

```bash
chmod +x ~/.hammerspoon/watchdog.sh
```

## Step 6: Reload Hammerspoon

```bash
open -a Hammerspoon
```

Tell the user: "Click the Hammerspoon icon in the menu bar → Reload Config. You should see 'Voice ready' overlay."

## Step 7: Test

Tell the user: "Press Right Cmd, say something, press Right Cmd again. The text should appear wherever your cursor is."

## Language config

Default language is Turkish (`-l tr`). To change:
- For auto-detection: change `"-l", "tr"` to `"-l", "auto"` in init.lua
- For English only: change to `"-l", "en"`
- For any other language: use the ISO 639-1 code
