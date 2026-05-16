# Agent Rocky Desktop

Agent Rocky is a local macOS desktop companion app. It gives you a small floating character near the Dock, a hover terminal for quick chat, configurable companion profiles, and bring-your-own-key model provider support.

The app is built with Swift, SwiftUI, and AppKit. It runs locally, stores conversations on your Mac, and stores provider API keys in macOS Keychain.

## What Works

- Floating transparent desktop companion.
- Menu-bar show, hide, and quit.
- Reopen behavior: launching the app again shows the companion if it was hidden.
- Mini hover terminal and larger stage mode.
- Multiple saved chats.
- Three bundled profiles: Rocky, Orange Cat, and Little Box Guy.
- Custom JSON profiles.
- Normal, thinking, and idle companion states.
- Occasional profile-owned idle actions.
- Optional image/GIF assets per animation.
- In-app preview buttons for normal, thinking, and idle states.
- BYOK provider settings for Codex CLI, OpenAI, OpenAI-compatible APIs, DeepSeek, Gemini, and Ollama.
- Unsigned local `.app` and `.dmg` packaging.

## Current Distribution Status

This repo is ready to publish as source and to build an unsigned local DMG.

The generated DMG is not Developer ID signed or notarized yet. That means macOS may show Gatekeeper warnings if someone downloads it from the internet. For a polished public binary release, add signing and notarization.

## Requirements

- macOS 14 or newer.
- Swift toolchain.
- One model backend:
  - authenticated `codex` CLI on `PATH`, or
  - a provider API key, or
  - a local Ollama endpoint.

## Build The DMG

```bash
scripts/build-release.sh
```

This runs tests, builds the app, creates the DMG, checks the plist, verifies codesign, and verifies the DMG checksum.

Expected local artifacts:

```text
dist/Agent Rocky.app
dist/AgentRocky.dmg
```

`dist/` is ignored by Git.

## Install Locally

Open `dist/AgentRocky.dmg`, then drag `Agent Rocky.app` to Applications.

Or install from the helper script:

```bash
scripts/package-macos-app.sh --install
```

The helper installs to `/Applications` when writable, otherwise to `~/Applications`.

## Run From Source

```bash
swift run
```

The companion appears near the Dock. Hover over it to open the small terminal.

## In-App Commands

Type these into the terminal:

```text
/open                open larger stage mode
/mini                return to small buddy mode
/hide                hide the floating panel
/new                 create a new chat
/chats               list recent chats
/profiles            list bundled profiles
/profile orange-cat  switch companion profile
/mode dynamic        let the companion move occasionally
/animate purr        run a profile-safe animation
```

## Configure Providers

Open stage mode with `/open`, then click the gear button.

You can configure:

- provider
- model
- base URL where supported
- API key
- agent prompt

Provider API keys are stored in macOS Keychain. Provider settings and conversations are stored under:

```text
~/Library/Application Support/AgentRocky/
```

## Profiles

Bundled profiles:

- `rocky`
- `orange-cat`
- `cute-buddy`

Custom profiles live in:

```text
~/Library/Application Support/AgentRocky/profiles/
```

See `docs/profile-schema.md` for the JSON format. Profiles can define the prompt, visual style, allowed animations, normal/thinking/idle states, idle timing, and optional image/GIF assets.

## Privacy

- Conversation history is stored locally in Application Support.
- API keys are stored in macOS Keychain.
- Codex CLI mode uses the user's local Codex configuration.
- BYOK modes send messages to the selected provider endpoint.
- Ollama mode uses the configured local Ollama endpoint.

## Repository Map

- `Sources/AgentRocky/App/` - AppKit app shell and floating panel.
- `Sources/AgentRocky/Brain/` - provider calls and response parsing.
- `Sources/AgentRocky/Domain/` - shared provider, response, and chat models.
- `Sources/AgentRocky/Persistence/` - conversations, preferences, custom profiles, and Keychain access.
- `Sources/AgentRocky/Profiles/` - profile schema and bundled profiles.
- `Sources/AgentRocky/UI/` - SwiftUI terminal, settings, stage, and renderers.
- `scripts/` - app packaging, DMG creation, and release checks.
- `docs/` - usage, profile schema, architecture, and release notes.

## Useful Docs

- `docs/how-to-use.md`
- `docs/profile-schema.md`
- `DESIGN.md`
- `PUBLIC_RELEASE_PLAN.md`

## Verification

```bash
swift test
scripts/build-release.sh
```

## License

MIT. See `LICENSE`.
