# Public Release Plan

## Current State

Agent Rocky is deployable as source plus an unsigned macOS DMG.

Done:

- Transparent floating macOS companion window.
- Menu-bar show, hide, and quit.
- Reopen handling so opening the app shows Rocky again.
- Mini hover terminal and larger stage mode.
- Multi-conversation persistence.
- Three bundled profiles: `rocky`, `orange-cat`, and `cute-buddy`.
- Custom JSON profiles from `~/Library/Application Support/AgentRocky/profiles/`.
- Profile-owned normal, thinking, and idle state configuration.
- Optional image/GIF assets per animation with SwiftUI renderer fallback.
- Idle action cooldown and random jitter per profile.
- In-app state preview buttons for normal, thinking, and idle.
- BYOK providers for OpenAI, OpenAI-compatible APIs, DeepSeek, Gemini, and Ollama.
- Codex CLI provider with persistent session resume.
- macOS Keychain storage for provider API keys.
- Generated app icon.
- `.app` and `.dmg` release scripts.
- Automated tests for profiles, provider defaults, conversations, migration, and response validation.

## Deployability

This is ready to publish as a public GitHub source repo and to share as an unsigned local DMG.

It is not yet a polished public binary release because it is not Developer ID signed or notarized. Users downloading the DMG from the internet may see Gatekeeper warnings until signing/notarization is added.

## Build Artifacts

Run:

```bash
scripts/build-release.sh
```

Expected output:

```text
dist/Agent Rocky.app
dist/AgentRocky.dmg
```

The release script runs tests, builds the app bundle, creates the DMG, lints the app plist, verifies codesign, and verifies the DMG checksum.

## Public Repo Checklist

- Keep the MIT license or replace the copyright name before publishing.
- Add screenshots or a short demo GIF.
- Add a GitHub repository description and topic tags.
- Do not commit `dist/`, `.build/`, or local Application Support data.
- Mention clearly that the first public DMG is unsigned.
- Use GitHub Releases for the DMG only after deciding whether unsigned distribution is acceptable.

## Remaining Release Gaps

- Developer ID signing and notarization.
- GitHub Actions macOS build check.
- Optional launch-at-login setting.
- Optional app auto-update path.
- Better custom profile editor UI instead of JSON-only profile files.
- More granular provider tests with mocked HTTP clients.

## Manual QA Before Public Release

1. Build with `scripts/build-release.sh`.
2. Open `dist/AgentRocky.dmg`.
3. Drag `Agent Rocky.app` to Applications.
4. Launch the app and confirm Rocky appears immediately.
5. Hide Rocky and reopen the app; Rocky should show again.
6. Open stage mode and use the gear panel.
7. Preview normal, thinking, and idle states.
8. Switch profiles between Rocky, Orange Cat, and Little Box Guy.
9. Send one Codex CLI message if Codex is authenticated.
10. Configure one BYOK provider and confirm fallback behavior is readable if credentials are missing.
