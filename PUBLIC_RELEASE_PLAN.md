# Public Release Plan

## Current State

Agent Rocky is a local macOS Swift prototype with:

- Transparent floating desktop companion.
- Hover terminal.
- Local Codex CLI brain.
- Multi-conversation persistence with old-chat selection.
- Stage mode for a larger chat window.
- Bundled companion profiles.
- Cinematic Rocky view and cozy cat view.
- Animation validation and profile-safe command animations.
- Basic automated tests plus manual build and launch checks.

It is closer to public source now, but custom profile loading, packaged app flow, screenshots/GIF, and broader UI polish still need hardening.

## Release Principle

Ship source first, not a binary.

The first public version should be easy for a developer to clone and run. A signed app bundle, launch-at-login behavior, and installer can come later after the core memory/profile model is stable.

## Phase 0: Public Repo Hygiene

Do this before pushing:

- Keep this MIT license or replace `Devdeep` with your preferred full author name.
- Remove local machine paths from docs.
- Add a clear requirement: macOS, Swift toolchain, and authenticated local `codex` CLI.
- Add a privacy note: messages are sent to whatever backend the user's local Codex CLI is configured to use.
- Add screenshots or a short demo GIF made from the app itself.
- Decide public naming. Avoid using movie/book screenshots, copied art, or marketing language that makes it look official.

Done criteria:

- `swift build` passes.
- README works from a fresh clone path.
- License is present.
- No local absolute paths are required.

## Phase 1: Conversation Persistence

Fix this before profile work.

Current issue:

- The app only stores one `memory.json`.
- `newChat()` deletes that memory.
- There is no old-chat picker.
- Reopen behavior depends on whether the single saved session id exists and was parsed correctly.

Target storage:

```text
~/Library/Application Support/AgentRocky/
  settings.json
  conversations/
    index.json
    <conversation-id>.json
  profiles/
    custom-profile.json
```

Conversation fields:

- `id`
- `title`
- `createdAt`
- `updatedAt`
- `codexSessionID`
- `profileID`
- `model`
- `terminalLines`
- `history`

Required behavior:

- Reopen app restores the last active conversation.
- New chat creates a new conversation instead of deleting old history.
- UI can select old conversations.
- UI can delete one conversation.
- If `codexSessionID` is missing, history still displays and the next message starts a new Codex session.

Done criteria:

- Close/reopen restores the same visible chat.
- New chat does not destroy older chats.
- Selecting an old chat resumes with its stored Codex session id.
- Unit tests cover load, save, migrate old `memory.json`, create new chat, and delete chat.

## Phase 2: Companion Profiles

Profiles should be app-level configuration, not hardcoded prompt branches. The project is not only Rocky. It should support any small companion: Rocky-like alien, cat, focus buddy, or user-defined custom creature.

Profile fields:

- `id`
- `name`
- `kind`
- `systemPrompt`
- `defaultModel`
- `visualStyle`
- `movementMode`
- `defaultAnimation`
- `allowedAnimations`
- `idleBehaviors`
- `accentColor`
- `temperatureStyle`

Bundled standard profiles:

- `rocky` - loyal, odd, practical companion.
- `desk-cat` - cozy cat that sleeps, licks, and plays in place.
- `wander-cat` - dynamic cat that can move around the screen.
- `focus-buddy` - direct low-noise work companion.

Custom profile behavior:

- Users can create JSON profiles in Application Support.
- Invalid profiles are ignored with a visible warning in the app.
- Profile selector changes both prompt and visual style.
- Conversation stores which profile it used.
- Any valid animation can be used with any profile, but the profile can restrict its allowed set.

Done criteria:

- Bundled profiles load without user files.
- Custom profiles override/add without editing source code.
- Invalid custom JSON cannot crash the app.
- UI can switch profile for a new chat.
- Profile can choose static or dynamic movement.

## Phase 3: Animation Registry

Decouple brain responses from raw Swift enum cases.

Standard animations:

- `idle`
- `walk`
- `wave`
- `think`
- `pulse`
- `sleep`
- `error`
- `excited`
- `rollInBox`
- `happyBounce`
- `workInPlace`
- `lick`
- `play`

Required behavior:

- Profile can choose allowed animations.
- Brain response is validated before touching UI.
- Unknown animation falls back to profile default.
- Visual style can map the same animation name differently.
- Static mode animates in place.
- Dynamic mode can move the companion across the screen with bounds and collision safety.
- Idle mode randomly chooses profile-safe idle behaviors like sleeping, licking, playing, looking around, or working.

Done criteria:

- Pixel style and cinematic style can both exist.
- Any profile can use any valid animation.
- Bad brain output cannot break rendering.
- Dynamic movement never pushes the terminal fully off-screen.
- Idle behaviors run without starting a Codex request.

## Phase 4: Testing

Minimum public test suite:

- `CodexBrain` argument construction.
- Codex JSON parsing.
- Missing/malformed Codex response fallback.
- Memory migration from old `memory.json`.
- Conversation create/select/delete.
- Profile load and validation.
- Animation validation fallback.
- Static vs dynamic movement config.

Manual tests:

- `swift build`
- `swift test`
- Launch app.
- Send one Codex-backed message.
- Close app and reopen.
- Resume old chat.
- Create new chat.
- Switch profile.
- Switch static/dynamic movement.
- Resize terminal.

## Phase 5: Packaging

Only after core state is stable:

- App icon.
- `.app` bundle build script.
- GitHub Actions macOS build check.
- Release notes.
- Optional signed/notarized build.
- Optional Homebrew cask later.

## Missing Ideas Worth Adding

- Menu bar icon with show/hide/quit.
- Pin position and remember window size.
- Import/export profiles.
- Export conversation as Markdown.
- Reset Codex session but keep visible chat history.
- Streaming response text later if Codex CLI support is good enough.
- Keyboard shortcut to open terminal.
- Accessibility labels for buttons.
- Clear troubleshooting page for Codex CLI auth and model selection.
- Companion playground for previewing profile + animation combinations.
- Per-profile idle schedule, for example cat sleeps after inactivity.
- Safe dynamic movement zones so the companion does not hide under the Dock or menu bar.

## Recommended Execution Order

1. Public hygiene and README cleanup.
2. Conversation store and old-chat picker.
3. Companion profile schema and bundled Rocky/cat/focus profiles.
4. Unit test harness for profiles, animation validation, and memory.
5. Animation registry and visual-style selector.
6. Static/dynamic movement engine.
7. Idle behavior scheduler.
8. Manual QA pass on close/reopen, new chat, old chat, resize, profile switch, movement mode, and fallback.
9. Demo screenshot/GIF.
10. Push public source repo.
11. Package `.app` only after early users can run source reliably.
