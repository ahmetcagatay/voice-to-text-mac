# Voice-to-Text for Mac

Talk to your Mac. It types for you. Works everywhere — Claude Code, Slack, browser, anywhere.

100% local. Zero cost. No API keys. 99+ languages.

## Setup

Open Claude Code and paste this:

```
Read the instructions at https://raw.githubusercontent.com/ahmet-cagatay/voice-to-text-mac/main/SETUP.md and follow them step by step. Install all dependencies, download the model, and configure Hammerspoon. Ask me before starting.
```

That's it. Claude Code handles the rest.

> **Tip:** If you don't want Claude to ask permission for every step, start it with `claude --dangerously-skip-permissions` and it will run the entire setup automatically.

## How it works

- **Right Cmd** → speak → **Right Cmd** again (toggle mode)
- **Hold Right Cmd 3+ seconds** → speak → release (hold mode)
- **Escape** to cancel

## Built with

- [Hammerspoon](https://www.hammerspoon.org/) — macOS automation
- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) — OpenAI's speech-to-text, runs locally
- [Sox](https://sox.sourceforge.net/) — audio recording

## Demo

https://github.com/user-attachments/assets/placeholder

## Author

[Ahmet Cagatay](https://www.linkedin.com/in/ahmet-cagatay) — built with Claude Code
