# Public Release Plan

## Current State

Agent Rocky is a local macOS Swift prototype with:

- Transparent floating desktop companion.
- Hover terminal.
- Local Codex CLI brain.
- One saved active session id and recent terminal memory.
- Cinematic SwiftUI creature view.
- Basic manual build and launch checks.

It is not ready for a clean public repo yet because session management, profile configuration, tests, packaging docs, and public-facing naming need hardening.

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

## Phase 2: Profiles

Profiles should be app-level configuration, not hardcoded prompt branches.

Profile fields:

- `id`
- `name`
- `systemPrompt`
- `defaultModel`
- `visualStyle`
- `defaultAnimation`
- `allowedAnimations`
- `accentColor`
- `temperatureStyle`

Bundled standard profiles:

- `rocky` - loyal, odd, practical companion.
- `pair-programmer` - direct engineering helper.
- `quiet-focus` - very short, low-noise desk buddy.
- `rubber-duck` - asks clarifying questions first.
- `debugger` - bug-first, evidence-first responses.

Custom profile behavior:

- Users can create JSON profiles in Application Support.
- Invalid profiles are ignored with a visible warning in the app.
- Profile selector changes both prompt and visual style.
- Conversation stores which profile it used.

Done criteria:

- Bundled profiles load without user files.
- Custom profiles override/add without editing source code.
- Invalid custom JSON cannot crash the app.
- UI can switch profile for a new chat.

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

Required behavior:

- Profile can choose allowed animations.
- Brain response is validated before touching UI.
- Unknown animation falls back to profile default.
- Visual style can map the same animation name differently.

Done criteria:

- Pixel style and cinematic style can both exist.
- Any profile can use any valid animation.
- Bad brain output cannot break rendering.

## Phase 4: Testing

Minimum public test suite:

- `CodexBrain` argument construction.
- Codex JSON parsing.
- Missing/malformed Codex response fallback.
- Memory migration from old `memory.json`.
- Conversation create/select/delete.
- Profile load and validation.
- Animation validation fallback.

Manual tests:

- `swift build`
- `swift test`
- Launch app.
- Send one Codex-backed message.
- Close app and reopen.
- Resume old chat.
- Create new chat.
- Switch profile.
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

## Recommended Execution Order

1. Public hygiene and README cleanup.
2. Conversation store and old-chat picker.
3. Unit test harness.
4. Profile schema and bundled profiles.
5. Animation registry and visual-style selector.
6. Manual QA pass on close/reopen, new chat, old chat, resize, and fallback.
7. Demo screenshot/GIF.
8. Push public source repo.
9. Package `.app` only after early users can run source reliably.
