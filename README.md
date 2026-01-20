<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Motive">
</p>

<h1 align="center">Motive</h1>

<p align="center">
  <strong>A minimalist personal AI companion for macOS that executes intents in the background.</strong><br>
  No chat windows, no distractions—just a silent partner that gets things done while you stay in your flow.
</p>

<p align="center">
  <a href="https://github.com/geezerrrr/motive/releases"><img src="https://img.shields.io/github/v/release/geezerrrr/motive?style=flat-square" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2015+-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <img src="assets/demo.gif" width="600" alt="Demo">
</p>

---

## Why Motive?

Traditional AI interfaces demand your attention. You type, wait, watch, respond, wait again. That's fine for questions—but absurd for tasks.

**Motive inverts this paradigm.** Describe what you want, then forget about it. The AI works silently in the background. You get interrupted only when a decision is needed.

Think of it as a competent colleague who handles tasks autonomously and only taps your shoulder when necessary.

## Features

- **Intent-first interaction** — Describe tasks in natural language via a Spotlight-like command bar
- **Background execution** — AI works while you focus on other things
- **Minimal interruption** — Permission requests and decisions surface only when required
- **Ambient status** — A subtle menu bar indicator shows progress without demanding attention
- **Local-first** — All data stays on your machine. Nothing is sent to the cloud except AI model requests.
- **Native experience** — Built with SwiftUI and AppKit for seamless macOS integration
- **Multi-provider** — Works with Claude, OpenAI, Gemini, or local Ollama

## Quick Start

### Install

Download the latest release for your architecture:

| Chip | Download |
|------|----------|
| Apple Silicon | [Motive-arm64.dmg](https://github.com/geezerrrr/motive/releases/latest) |
| Intel | [Motive-x86_64.dmg](https://github.com/geezerrrr/motive/releases/latest) |

> First launch: Right-click → Open (or run `xattr -cr /Applications/Motive.app`)

### Configure

1. Click the menu bar icon → **Settings**
2. Select your AI provider (Claude / OpenAI / Gemini / Ollama)
3. Enter your API key

### Use

1. Press `⌥Space` to summon the command bar
2. Describe what you want done
3. Press Enter — the bar disappears, you're free
4. Check the menu bar icon for status; click to view details

## Build from Source

```bash
git clone https://github.com/geezerrrr/motive.git
cd Motive
open Motive.xcodeproj
```

The OpenCode binary is bundled automatically during release builds. For development, place it at `Motive/Resources/opencode`.

## Requirements

- macOS 15.0 (Sequoia) or later
- API key for Claude, OpenAI, Gemini, or local Ollama setup

## Acknowledgments

Powered by [OpenCode](https://github.com/opencode-ai/opencode) — the open-source AI agent that makes autonomous task execution possible.

## License

[MIT](LICENSE)

---

<p align="center">
  <sub>Let AI work. Stay in your flow.</sub>
</p>
