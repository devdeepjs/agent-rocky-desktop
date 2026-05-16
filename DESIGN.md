# Agent Rocky Desktop

## Goal

Build a small macOS desktop companion app that is configurable by profile and provider. Rocky is a bundled profile. Codex CLI is a bundled provider. Neither one is the core architecture.

The app should provide:

- A transparent floating desktop character near the Dock.
- A tiny terminal that appears only on hover or in stage mode.
- Menu-bar show/hide/quit behavior so the app can stay running.
- In-app provider, model, base URL, API key, and prompt configuration.
- A downloadable DMG for local installation.
- A profile model that can support Rocky, a cat, a little box buddy, or any later custom companion.

## Shape

```text
SwiftUI macOS app
  AppKit floating NSPanel
    RootView
      transparent desktop overlay
      custom animated character
      hover terminal
  BrainService
    Codex CLI provider
    OpenAI Responses provider
    OpenAI-compatible chat-completions provider
    DeepSeek provider
    Gemini provider
    Ollama provider
    JSON response parser and local fallback
  ConversationStore
    saves terminal history
    saves recent turns
    saves active Codex session id
    saves provider/model/baseURL/prompt preferences
    loads custom JSON profiles
  KeychainSecretStore
    stores provider API keys by provider id
```

## Brain Contract

The UI asks the selected provider for one structured response:

```json
{
  "text": "Good good good. You work smart.",
  "mood": "happy",
  "animation": "bounce"
}
```

The app validates the animation against the active profile before rendering. Bad or missing JSON falls back to a local response so the UI does not break.

## Profile Contract

Profiles carry the behavior and visual contract:

- `id`
- `name`
- `kind`
- `systemPrompt`
- `defaultModel`
- `visualStyle`
- `movementMode`
- `defaultAnimation`
- `allowedAnimations`
- `states.normal`
- `states.thinking`
- `states.idle`
- `states.idleCooldownSeconds`
- `states.idleJitterSeconds`
- `states.animationAssets`
- `idleBehaviors`
- `accentColorHex`

The bundled profiles are `rocky`, `orange-cat`, and `cute-buddy`. Custom profile files can be placed under `~/Library/Application Support/AgentRocky/profiles/`. Image and GIF assets can be attached per animation; the SwiftUI renderer remains the fallback when an asset is missing.

## Provider Contract

The bundled provider ids are:

- `codex-cli`
- `openai`
- `openai-compatible`
- `deepseek`
- `gemini`
- `ollama`

Codex CLI uses the user's local Codex login and can resume a saved session id. BYOK providers use per-provider Keychain secrets. Ollama uses the configured local base URL and does not require a key.

## Release Contract

`scripts/build-release.sh` is the release smoke path. It runs tests, builds `dist/Agent Rocky.app`, creates `dist/AgentRocky.dmg`, lints the plist, verifies codesign, and verifies the DMG.

The current DMG is unsigned. Signed and notarized distribution is a later release task.
