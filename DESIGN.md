# Agent Rocky Desktop

## Goal

Build a small macOS desktop buddy inspired by the reel:

- A transparent floating desktop character near the Dock.
- Cute 8-bit Rocky-style body inspired by the reference image.
- No always-visible chat box, speech bubble, or title label.
- A tiny terminal opens only on hover/focus.
- The transparent panel is resizable so the terminal size can change.
- A brain powered by the local `codex` CLI, not an OpenAI API key.
- A safe fallback mode with canned lines when Codex is unavailable.

This is a local prototype, not an App Store architecture.

## Shape

```text
SwiftUI macOS app
  AppKit floating NSPanel
    RockyRootView
      transparent desktop overlay
      custom 8-bit character
      hover terminal
  CodexBrain
    runs codex exec non-interactively
    asks for JSON only
    parses text/mood/animation
    falls back to canned response
```

## Brain Contract

The UI asks the brain for one structured response:

```json
{
  "text": "Good good good. You work smart.",
  "mood": "happy",
  "animation": "bounce"
}
```

The app will send Codex a tight prompt:

- stay in tiny desktop buddy character
- short answer only
- return JSON only
- no shell commands or file edits

The command shape is:

```bash
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never -o /tmp/agent-rocky-response.json -
```

The app does not hardcode a model by default. It lets Codex use the user's configured model. A small optional override field exists for model names that are actually available locally.

Current local evidence:

- `~/.codex/config.toml` default model: `gpt-5.5`
- bundled model catalog: `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.3-codex`, `gpt-5.2`, `codex-auto-review`
- `opus` was not present in the local Codex model catalog checked from this environment

## Visual Decode

The reel composition is not a normal app window. It looks like:

- space/Earth desktop wallpaper stays visible
- a small Rocky-like desktop companion sits above the Dock
- any active app window is behind the companion
- the companion feels like it belongs on the desktop, not inside a rounded card

This implementation keeps the panel borderless and transparent. The visible default is just the small animated Rocky. The terminal is hidden until hover so the desktop does not look like a chat app.

## Why Direct CLI First

Direct `codex exec` is the smallest working path because it reuses the user's existing Codex login and model access. The experimental Codex app server and exec server can be explored later if the prototype needs streaming, session reuse, or lower latency.

## Deferred

- Voice input.
- macOS text-to-speech.
- Persistent memory.
- Codex session reuse.
- App icon and packaged `.app` bundle.
