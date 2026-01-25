<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Motive - AI Agent for macOS">
</p>

<h1 align="center">Motive</h1>

<h3 align="center"><strong>Say it. Walk away.</strong></h3>
<p align="center">The AI agent that works while you don't watch. Lives in your menu bar, finds you when needed.</p>

<p align="center">
  <a href="https://github.com/geezerrrr/motive/releases"><img src="https://img.shields.io/badge/Download-v0.3.0-22c55e?style=flat-square" alt="Download"></a>
  <a href="https://github.com/geezerrrr/motive/stargazers"><img src="https://img.shields.io/github/stars/geezerrrr/motive?style=flat-square&color=22c55e" alt="Stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-22c55e?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS%2015+-Native-0ea5e9?style=flat-square" alt="macOS">
  <img src="https://img.shields.io/badge/Swift%206-SwiftUI-f97316?style=flat-square" alt="Swift">
</p>

<p align="center">
  <a href="https://github.com/geezerrrr/motive/releases/latest/download/Motive-arm64.dmg"><strong>Download for Mac (Apple Silicon)</strong></a>
  ·
  <a href="https://github.com/geezerrrr/motive/releases/latest/download/Motive-x86_64.dmg">Intel Mac</a>
  ·
  <a href="https://github.com/geezerrrr/motive/releases">All Releases</a>
</p>

<br />

---

<br />

## What makes it different

<table>
<tr>
<td width="50%" valign="top" align="center">

### 🎯 Background-first

<div align="left">

- AI runs in the background, not in a window
- Submit a task, go back to your work
- No need to babysit the AI

</div>

</td>
<td width="50%" valign="top" align="center">

### 📍 Menu bar native

<div align="left">

- Lives in your menu bar, always accessible
- Permission requests drop down as popups
- Never miss a prompt, never switch apps

</div>

</td>
</tr>
<tr>
<td width="50%" valign="top" align="center">

### 🔐 Local & private

<div align="left">

- All data stays on your machine
- Bring your own API keys
- Run fully offline with Ollama

</div>

</td>
<td width="50%" valign="top" align="center">

### ⚡ Native macOS

<div align="left">

- Built with SwiftUI & AppKit
- No Electron, no web views
- Fast, lightweight, beautiful

</div>

</td>
</tr>
</table>

<br />

<br />

## The problem with AI tools today

| | Desktop Apps | CLI Tools | **Motive** |
|:--|:--|:--|:--|
| **Where it lives** | App window you must watch | Terminal you must keep open | Menu bar — always there |
| **When AI needs input** | Buried in the app UI | Blocks with `[Y/n]` | Popup drops down to find you |
| **Switch away?** | Miss the response | Hangs silently | AI finds you when ready |
| **Your attention** | Hostage | Hostage | **Free** |

**Cursor, Claude Desktop, Claude Code, Gemini CLI** — they all demand your attention.

**Motive** lets you walk away. The AI works. You work. When it needs you, it taps your shoulder.

<br />


<br />

## Demo

<p align="center">

https://github.com/user-attachments/assets/6209e3d9-60db-4166-a14a-ae90cdbc01d6

</p>

<br />


<br />

## Use cases

| | | |
|:--|:--|:--|
| **💻 Code & Dev** | **📁 File Management** | **🌐 Browser Tasks** |
| Refactor code across files | Organize downloads by type | Research and summarize |
| Generate boilerplate | Batch rename with rules | Fill forms automatically |
| Write tests and docs | Clean up duplicates | Web scraping workflows |

<br />


<br />

## Quick start

> **2 minutes to get started.**

| Step | Action |
|:----:|--------|
| **1** | **[Download](https://github.com/geezerrrr/motive/releases/latest/download/Motive-arm64.dmg)** and drag to Applications |
| **2** | Click menu bar icon → **Settings** → Add your API key |
| **3** | Press `⌥Space` → Describe your task → Press Enter |
| **4** | Walk away. Check menu bar for status. |

<br />

### Supported AI providers

- **Anthropic** (Claude)
- **OpenAI** (GPT-4, GPT-4o)
- **Google** (Gemini)
- **Ollama** (Local models — fully offline)

<br />


<br />

## Keyboard shortcuts

| Shortcut | Action |
|:--------:|--------|
| `⌥Space` | Summon command bar |
| `↵` | Submit task |
| `Esc` | Dismiss |
| `⌘,` | Settings |

<br />


<br />

## Roadmap

### Completed
- [x] **Multi-language UI** — English, 简体中文, 日本語
- [x] **Browser automation** — Web scraping, form filling, browser workflows

### In Progress
- [ ] **Multi-task queue** — Queue tasks, run independent ones in parallel
- [ ] **Task resume** — Interrupt and resume long-running tasks

### Planned
- [ ] **Custom Skills** — Define your own skills in `~/.motive/skills/`
- [ ] **Personal Profile** — AI remembers your preferences and context
- [ ] **Memory & RAG** — Long-term memory for context-aware assistance
- [ ] **Task templates** — Save and reuse common workflows

<br />


<br />

## Build from source

```bash
git clone https://github.com/geezerrrr/motive.git
cd motive
open Motive.xcodeproj
```

<details>
<summary><strong>Requirements</strong></summary>

- macOS 15.0 (Sequoia) or later
- Xcode 16+
- For release builds, OpenCode binary is bundled automatically

</details>

<br />


<br />

## FAQ

<details>
<summary><strong>How is this different from Cursor / Claude Desktop?</strong></summary>

They lock you in a window. Motive lives in your menu bar. You submit a task, walk away, and the AI finds you when it needs input.

Think of it this way: desktop apps are like a colleague who insists you sit in their office. Motive is like a colleague who handles everything autonomously and only taps your shoulder when necessary.
</details>

<details>
<summary><strong>Is my data sent anywhere?</strong></summary>

Motive is local-first. Sessions and history stay on your machine. The only network traffic is API requests to your chosen AI provider. Use Ollama for 100% offline operation.
</details>

<details>
<summary><strong>Why does it need Accessibility permission?</strong></summary>

To register the global hotkey (`⌥Space`) that summons the command bar from anywhere on your Mac.
</details>

<details>
<summary><strong>Can I use local models?</strong></summary>

Yes. Select Ollama as your provider and point it to your local instance. Zero cloud dependency.
</details>

<br />


<br />

## Acknowledgments

Built on the shoulders of giants:

- [OpenCode](https://github.com/sst/opencode) — The open-source AI coding agent that powers task execution
- [browser-use](https://github.com/browser-use/browser-use) — AI browser automation that makes web tasks possible

<br />


<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-22c55e.svg?style=for-the-badge" alt="MIT License"></a>
</p>

<p align="center">
  <sub><strong>Let AI wait for you, so you don't have to wait for it.</strong></sub>
</p>

<p align="center">
  <a href="https://github.com/geezerrrr/motive/stargazers">⭐ Star on GitHub</a>
</p>


<!-- 
Keywords: AI agent, AI assistant, macOS AI, menu bar AI, background AI agent, autonomous AI, agentic AI,
Claude Desktop alternative, Cursor alternative, ChatGPT alternative, Copilot alternative, Gemini CLI alternative,
OpenCode GUI, local LLM, Ollama GUI, private AI, on-device AI, offline AI,
Spotlight AI, Raycast alternative, Alfred alternative, macOS menu bar app,
AI automation, AI workflow, task automation, no-code AI, AI for developers,
Claude API, OpenAI API, Gemini API, Anthropic, GPT-4, Claude Sonnet,
SwiftUI app, native macOS app, Apple Silicon, M1 M2 M3 M4 Mac,
AI productivity, developer tools, code generation, AI code review,
natural language interface, intent-based AI, AI copilot,
open source AI, free AI assistant, self-hosted AI, privacy-first AI,
file management AI, browser automation, web scraping, form filling,
personal AI assistant, background task runner, macOS automation
-->
