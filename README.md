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
  <a href="https://github.com/geezerrrr/motive/stargazers"><img src="https://img.shields.io/github/stars/geezerrrr/motive?style=flat-square" alt="Stars"></a>
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
- **Local-first** — All data stays on your machine. Nothing is sent to the cloud except AI model requests
- **Native experience** — Built with SwiftUI and AppKit for seamless macOS integration
- **Multi-provider** — Works with Claude, OpenAI, Gemini, or local Ollama

## Quick Start

### Install

Download the latest release for your architecture:

| Chip | Download |
|------|----------|
| Apple Silicon | [Motive-arm64.dmg](https://github.com/geezerrrr/motive/releases/latest) |
| Intel | [Motive-x86_64.dmg](https://github.com/geezerrrr/motive/releases/latest) |

> **First launch:** Right-click → Open (or run `xattr -cr /Applications/Motive.app`)

### Configure

1. Click the menu bar icon → **Settings**
2. Select your AI provider (Claude / OpenAI / Gemini / Ollama)
3. Enter your API key

### Use

1. Press `⌥Space` to summon the command bar
2. Describe what you want done
3. Press Enter — the bar disappears, you're free
4. Check the menu bar icon for status; click to view details

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥Space` | Open command bar |
| `↵` | Submit intent |
| `Esc` | Dismiss command bar |
| `⌘,` | Open settings |

## Build from Source

```bash
git clone https://github.com/geezerrrr/motive.git
cd motive
open Motive.xcodeproj
```

The OpenCode binary is bundled automatically during release builds. For development, place it at `Motive/Resources/opencode`.

## Requirements

- macOS 15.0 (Sequoia) or later
- API key for Claude, OpenAI, Gemini, or local Ollama setup

## FAQ

<details>
<summary><strong>Why does Motive need Accessibility permission?</strong></summary>

Accessibility permission is required to register the global hotkey (`⌥Space`) that summons the command bar from anywhere on your system. Without it, you can only use Motive by clicking the menu bar icon.
</details>

<details>
<summary><strong>Is my data sent to the cloud?</strong></summary>

Motive is local-first. Your conversations and session history are stored only on your machine. The only network traffic is between Motive and your chosen AI provider (Claude, OpenAI, Gemini, or local Ollama) when processing intents.
</details>

<details>
<summary><strong>Can I use Motive with a local LLM?</strong></summary>

Yes! Select "Ollama" as your provider and point it to your local Ollama instance. This keeps everything on your machine with zero cloud dependency.
</details>

<details>
<summary><strong>How is this different from ChatGPT/Claude web apps?</strong></summary>

Traditional AI interfaces are chat-centric—you watch the conversation unfold. Motive is task-centric—you describe what you want, then continue your work while AI handles it in the background. You only get interrupted when a decision is needed.
</details>

<details>
<summary><strong>What can I ask Motive to do?</strong></summary>

Anything you'd ask an AI coding assistant: refactor code, generate files, run scripts, organize projects, write documentation, and more. Motive passes your intent to OpenCode, which has full access to your filesystem and terminal.
</details>

## Roadmap

- [ ] **Multi-task concurrency** — Run multiple tasks in parallel with independent progress tracking
- [ ] **Browser automation** — Full support for web scraping, form filling, and browser-based workflows
- [ ] **Task templates** — Save and reuse common task patterns with customizable parameters
- [ ] **Multi-language UI** — Localized interface for global users
- [ ] Homebrew Cask distribution

## Acknowledgments

Powered by [OpenCode](https://github.com/opencode-ai/opencode) — the open-source AI agent that makes autonomous task execution possible.

---

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="MIT License"></a>
</p>

<p align="center">
  <sub>Let AI work. Stay in your flow.</sub>
</p>

<p align="center">
  <a href="https://github.com/geezerrrr/motive/stargazers">⭐ Star us on GitHub</a>
</p>

---

<!-- SEO Keywords -->
<!-- 
Cowork | Openwork | AI Agent | AI Assistant | macOS AI | Background AI | Autonomous AI Agent | AI Coding Assistant |
Claude Desktop Alternative | ChatGPT Alternative | Cursor Alternative | Copilot Alternative |
OpenCode GUI | Local LLM | Ollama GUI | Private AI | On-device AI |
Spotlight AI | Raycast Alternative | Alfred Alternative | macOS Menu Bar App |
AI Automation | AI Workflow | Task Automation | No-code AI | AI for Developers |
Claude API | OpenAI API | Gemini API | Anthropic | GPT-4 | Claude Sonnet |
SwiftUI | Native macOS App | Apple Silicon | M1 M2 M3 M4 |
AI Productivity | Developer Tools | Code Generation | AI Code Review |
Natural Language Interface | Intent-based AI | Agentic AI | AI Copilot |
Open Source AI | Free AI Assistant | Self-hosted AI | Privacy-first AI
-->

