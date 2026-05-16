# How To Use Agent Rocky

## Install From This Repo

Build the release artifacts:

```bash
scripts/build-release.sh
```

Open:

```text
dist/AgentRocky.dmg
```

Drag `Agent Rocky.app` into Applications. If you install from the helper script instead, it will copy the app to `/Applications` when writable or `~/Applications` otherwise:

```bash
scripts/package-macos-app.sh --install
```

## Launch And Restore

Launch `Agent Rocky.app` from Applications. Rocky should appear near the Dock immediately.

The app is a menu-bar utility. If Rocky is hidden, open the app again or use the menu-bar item to show it. The red `x` hides the panel; it does not quit the app.

## Basic Chat

Hover over Rocky to show the small terminal. Type a message and press return.

Useful commands:

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

## Configure The Brain

Open stage mode and click the gear button.

You can configure:

- provider
- model
- base URL where supported
- provider API key
- agent prompt

Supported providers:

- Codex CLI
- OpenAI
- OpenAI-compatible
- DeepSeek
- Gemini
- Ollama

API keys are saved in macOS Keychain. Settings and conversations are saved in `~/Library/Application Support/AgentRocky/`.

## Preview Profile States

In the gear panel, use:

- `Normal`
- `Thinking`
- `Idle`

These preview the active profile's three state groups without sending a chat message.

## Add A Custom Profile

Create a JSON file in:

```text
~/Library/Application Support/AgentRocky/profiles/
```

Use `docs/profile-schema.md` as the format reference. Restart the app after adding the profile.

Profiles can define:

- normal animation
- thinking animation
- idle animation pool
- idle cooldown and jitter
- optional image/GIF assets per animation
- allowed animations
- system prompt
- visual style

## Current Distribution Status

The generated DMG is unsigned. It is fine for local testing and source-based sharing. For broader public distribution, add Developer ID signing and notarization.
