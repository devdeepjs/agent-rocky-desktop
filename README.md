# Agent Rocky Desktop

Local macOS desktop buddy prototype powered by the local Codex CLI.

## Run

```bash
cd /Users/sdevdeep/Desktop/poc/agent-rocky-desktop
swift run
```

Run `swift build && swift run` if you want both in one line. Do not use `swift build | swift run`; that pipes build output into the app process and makes debugging launch behavior harder.

The app opens a transparent floating pixel Rocky near the Dock. By default only the little character is visible. Hover over it to open the tiny terminal, type, and press enter.

## Brain

The app calls Codex without a hardcoded model by default:

```bash
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never -o /tmp/agent-rocky-response.json -
```

The model field is only an override. From this machine, `~/.codex/config.toml` says the configured default is `gpt-5.5`; the bundled catalog shows `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.3-codex`, `gpt-5.2`, and `codex-auto-review`. `opus` was not shown by the local Codex model catalog checked here.

If Codex fails, times out, or returns malformed JSON, the UI falls back to a canned local response instead of breaking.

The tiny dot in the terminal title bar shows brain status:

- green: Codex response was used
- red: local fallback was used

## Files

- `DESIGN.md` - architecture and contract.
- `Sources/AgentRocky/RockyRootView.swift` - hover terminal and pixel character drawing.
- `Sources/AgentRocky/CodexBrain.swift` - Codex CLI bridge.
- `Sources/AgentRocky/RockyViewModel.swift` - interaction state.

## Verified Here

```bash
swift build
codex debug models --bundled
rg -n '^model = ' /Users/sdevdeep/.codex/config.toml
```

`codex exec` could not be fully smoke-tested inside this sandbox because the sandbox cannot access `/Users/sdevdeep/.codex/sessions`. Running from your normal terminal should use your real Codex session.
