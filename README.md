# Agent Rocky Desktop

Local macOS desktop companion app with configurable character profiles and bring-your-own-key model providers.

## Status

Working local macOS app. It builds a downloadable unsigned DMG under `dist/AgentRocky.dmg`. It is ready for source publishing and local DMG testing; Developer ID signing and notarization are still needed for a polished public binary release.

## Requirements

- macOS 14 or newer
- Swift toolchain
- Authenticated `codex` CLI on `PATH`, or an API key/local endpoint for another configured provider

## Downloadable App

Build and verify the release artifacts:

```bash
scripts/build-release.sh
```

That writes:

- `dist/Agent Rocky.app`
- `dist/AgentRocky.dmg`

Open the DMG and drag `Agent Rocky.app` to Applications.

For full usage, provider setup, and custom profile instructions, see `docs/how-to-use.md`.

## Local Run

```bash
swift run
```

The app opens a transparent floating companion near the Dock. By default only the character is visible. Hover over it to open the tiny terminal, type, and press enter.

## Build The App Bundle Only

```bash
scripts/package-macos-app.sh
```

That writes `dist/Agent Rocky.app`. To install it into `/Applications` when writable, or `~/Applications` otherwise:

```bash
scripts/package-macos-app.sh --install
```

The app runs as a menu-bar utility. Use the red `x` button or `/hide` to hide the floating panel, then restore it from the menu-bar item without rebuilding.

## Commands

Type these in the terminal:

```text
/open                open larger stage mode
/mini                return to small buddy mode
/hide                hide the floating panel
/new                 create a new chat
/chats               list recent chats
/profiles            list bundled profiles
/profile orange-cat  switch companion profile
/mode dynamic        let the small companion move around the safe screen area
/animate purr        run a profile-safe animation
```

Bundled profiles currently include `rocky`, `orange-cat`, and `cute-buddy`. Custom profile JSON files can be placed in `~/Library/Application Support/AgentRocky/profiles/`; see `docs/profile-schema.md`. Profiles can define normal, thinking, and idle actions, including optional image/GIF assets per animation.

## Brain And BYOK

Open stage mode and click the gear button to configure provider, model, base URL, API key, and the active agent prompt. The same panel has preview buttons for the current profile's normal, thinking, and idle states. Bundled providers are:

- Codex CLI
- OpenAI
- OpenAI-compatible
- DeepSeek
- Gemini
- Ollama

Codex CLI is the default provider. The first message starts a persistent Codex session without a hardcoded model:

```bash
codex exec --skip-git-repo-check --sandbox read-only --color never --json -o /tmp/agent-rocky-response.json -
```

Later messages resume the saved session:

```bash
codex exec resume --skip-git-repo-check --json -o /tmp/agent-rocky-response.json <session-id> -
```

API keys are stored in macOS Keychain per provider. Provider, model, base URL, prompt, terminal history, recent turns, and Codex session ids are saved under Application Support as `AgentRocky/`.

If the selected provider fails, times out, or returns malformed JSON, the UI falls back to a canned local response instead of breaking.

## Privacy

In Codex mode, messages go through the local `codex` CLI and follow that user's Codex configuration. In BYOK modes, messages are sent to the selected provider endpoint with that provider's Keychain-stored API key. Ollama uses the configured local endpoint. Conversation text and settings are stored under `~/Library/Application Support/AgentRocky/`.

## Files

- `DESIGN.md` - architecture and contract.
- `PUBLIC_RELEASE_PLAN.md` - public release execution order.
- `docs/how-to-use.md` - install, launch, provider setup, and profile usage.
- `docs/profile-schema.md` - custom companion profile format.
- `scripts/build-release.sh` - test, bundle, DMG, and verification flow.
- `scripts/package-macos-app.sh` - local `.app` bundle builder.
- `scripts/create-dmg.sh` - DMG builder.
- `Sources/AgentRocky/App/` - AppKit app shell and floating panel.
- `Sources/AgentRocky/Brain/BrainService.swift` - Codex CLI, OpenAI, compatible, DeepSeek, Gemini, and Ollama adapters.
- `Sources/AgentRocky/Domain/BrainModels.swift` - provider, response, and chat models.
- `Sources/AgentRocky/Profiles/BundledProfiles.swift` - shared profile data model and bundled profiles.
- `Sources/AgentRocky/UI/` - SwiftUI terminal, stage, and renderers.
- `Sources/AgentRocky/Persistence/` - saved chats, preferences, profiles, and Keychain secrets.

## Verified Here

```bash
swift test
scripts/build-release.sh
```

## License

MIT. Copyright (c) 2026 Devdeep.
