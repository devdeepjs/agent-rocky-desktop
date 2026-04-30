# Agent Rocky Desktop

Local macOS desktop companion powered by the user's authenticated Codex CLI.

## Status

Prototype. The app is fun and runnable locally, but public-release hardening is tracked in `PUBLIC_RELEASE_PLAN.md`.

## Requirements

- macOS
- Swift toolchain
- Authenticated `codex` CLI available on `PATH`

## Run

```bash
swift run
```

Run `swift build && swift run` if you want both in one line. Do not use `swift build | swift run`; that pipes build output into the app process and makes debugging launch behavior harder.

The app opens a transparent floating companion near the Dock. By default only the character is visible. Hover over it to open the tiny terminal, type, and press enter.

## Brain

The first message starts a persistent Codex session without a hardcoded model by default:

```bash
codex exec --skip-git-repo-check --sandbox read-only --color never --json -o /tmp/agent-rocky-response.json -
```

Later messages resume the saved session:

```bash
codex exec resume --skip-git-repo-check --json -o /tmp/agent-rocky-response.json <session-id> -
```

Terminal history, recent turns, and the active Codex session id are saved under Application Support as `AgentRocky/memory.json`. Use the plus-bubble button in the terminal title bar to start a new chat and clear that saved session.

The model field is only an override. Leave it blank to let Codex use the user's configured default model.

If Codex fails, times out, or returns malformed JSON, the UI falls back to a canned local response instead of breaking.

The tiny dot in the terminal title bar shows brain status:

- green: Codex response was used
- red: local fallback was used

## Public Release Plan

See `PUBLIC_RELEASE_PLAN.md` for the ordered path to a public repo: conversation persistence, old-chat selection, profiles, animation registry, tests, packaging, and release hygiene.

## Privacy

The app does not use an OpenAI API key directly. It sends prompts through the local `codex` CLI, so messages go wherever that user's Codex CLI is configured to send them.

## Files

- `DESIGN.md` - architecture and contract.
- `PUBLIC_RELEASE_PLAN.md` - public release execution order.
- `LICENSE` - MIT license.
- `Sources/AgentRocky/RockyRootView.swift` - hover terminal and companion drawing.
- `Sources/AgentRocky/CodexBrain.swift` - Codex CLI bridge.
- `Sources/AgentRocky/RockyViewModel.swift` - interaction state.
- `Sources/AgentRocky/RockyMemoryStore.swift` - saved session and terminal memory.

## Verified Here

```bash
swift build
.build/debug/AgentRocky
```

The direct binary smoke test launches the panel and prints its frame.

## License

MIT. Copyright (c) 2026 Devdeep.
