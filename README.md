<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Motive">
</p>

<h1 align="center">Motive</h1>

<h3 align="center"><strong>Say it. Walk away.</strong></h3>
<p align="center">A personal AI agent for macOS. Turns intent into completed work, running from your menu bar.</p>

<p align="center">
  <a href="https://github.com/geezerrrr/motive/releases"><img src="https://img.shields.io/badge/release-v0.7.0-blue?style=flat-square" alt="Release"></a>
  <a href="https://github.com/geezerrrr/motive/stargazers"><img src="https://img.shields.io/github/stars/geezerrrr/motive?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2015+-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License"></a>
</p>

---

## Why Motive?

Today's AI tools keep you hostage — Cursor locks you in a window, Claude Code blocks your terminal. Switch away, and you'll miss prompts or return to a stale `[Y/n]` that's been waiting for minutes.

**Motive lives in your menu bar.** AI works in the background. When it needs you, a lightweight popup drops down from the menu bar — no need to switch apps. One click, done, back to your flow.

| | Desktop Apps | CLI Tools | **Motive** |
|---|---|---|---|
| **Where it lives** | App window | Terminal | Menu bar |
| **Permission prompts** | Buried in UI | Blocks terminal | Menu bar popup |
| **Switch apps?** | Miss responses | Hangs silently | AI finds you |

## Features

- **Intent-first** — Describe tasks in natural language, press Enter, done. No conversation needed.
- **True background execution** — AI works as a background process, like compiling or rendering.
- **Menu bar notifications** — Permission requests drop down from the menu bar, not buried in an app window.
- **Ambient status** — A subtle menu bar icon shows progress without demanding attention.
- **You are the final arbiter** — Like macOS system permission dialogs, you approve only what matters.
- **Local-first** — All data stays on your machine. Only AI API requests leave your device.
- **Native macOS** — Built with SwiftUI and AppKit. No Electron, no web views.
- **Multi-provider** — Claude, OpenAI, Gemini, or fully local with Ollama.

## Screenshots & Demo

<p align="center">

https://github.com/user-attachments/assets/6209e3d9-60db-4166-a14a-ae90cdbc01d6

</p>

## Quick Start

### Install

Download the latest release for your architecture:

| Chip | Download |
|------|----------|
| Apple Silicon | [Motive-arm64.dmg](https://github.com/geezerrrr/motive/releases/latest/download/Motive-arm64.dmg) |
| Intel | [Motive-x86_64.dmg](https://github.com/geezerrrr/motive/releases/latest/download/Motive-x86_64.dmg) |

> **First launch:** If blocked, go to System Settings → Privacy & Security → Click "Open Anyway"

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
<summary><strong>How is this different from Cursor / Claude Desktop / Claude Code / Gemini CLI?</strong></summary>

**Desktop apps** (Cursor, Claude Desktop) are **window-locked** — you must stay in their interface.

**CLI tools** (Claude Code, Gemini CLI) are **terminal-locked** — if you switch away, the terminal hangs waiting for input. You come back to find a cryptic `[Y/n]` prompt that's been sitting there for 20 minutes.

**Motive** lives in your menu bar — the AI runs as a background process. When it needs your input, a popup drops down from the menu bar. One click, done, back to your flow.

Think: desktop apps are like a colleague who insists you sit in their office. CLI tools are like someone who emails you but marks it "urgent" with no notification. Motive is like a colleague who taps your shoulder only when necessary, handles everything else autonomously.
</details>

<details>
<summary><strong>Why does Motive need Accessibility permission?</strong></summary>

To register the global hotkey (`⌥Space`) that summons the command bar from anywhere. Without it, you'd need to click the menu bar icon every time.
</details>

<details>
<summary><strong>Is my data sent to the cloud?</strong></summary>

Motive is local-first. Sessions and history stay on your machine. The only network traffic is API requests to your chosen AI provider. Use Ollama for 100% offline operation.
</details>

<details>
<summary><strong>Can I use a local LLM?</strong></summary>

Yes. Select Ollama as your provider and point it to your local instance. Zero cloud dependency.
</details>

<details>
<summary><strong>What can Motive do?</strong></summary>

Anything an AI coding agent can do: refactor code, generate files, run scripts, organize projects, write docs, and more. Motive passes your intent to OpenCode, which has full filesystem and terminal access.
</details>

## Roadmap

### Completed
- [x] **Multi-language UI** — English, 简体中文, 日本語
- [x] **Browser automation** — Full support for web scraping, form filling, and browser-based workflows
- [x] **Skills System** — 50+ bundled skills (weather, GitHub, Slack, Notion, etc.) with easy enable/disable in Settings
- [x] **Custom Skills** — User-defined skills via `~/.motive/skills/` directory, no code required

### In Progress
- [ ] **Multi-task queue** — Task queuing with parallel execution for independent tasks and sequential processing for dependent ones
- [ ] **Task resume** — Interrupt and resume long-running tasks, preserving state across app restarts

### Planned
- [x] **Personal Profile** — Store personal context (name, preferences, work style) for more relevant AI responses
- [ ] **Memory & RAG** — Long-term memory with retrieval-augmented generation for context-aware assistance
- [ ] **Task templates** — Save and reuse common task patterns with customizable parameters

## Acknowledgments

Powered by [OpenCode](https://github.com/anomalyco/opencode) — the open-source AI coding agent that makes autonomous task execution possible.

---

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="MIT License"></a>
</p>

<p align="center">
  <sub>Let AI wait for you, so you don't have to wait for it.</sub>
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

