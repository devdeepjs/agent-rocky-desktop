# Distribution DMG

## Target Artifact

The user-facing release artifact is:

```text
dist/AgentRocky.dmg
```

The DMG contains:

```text
Agent Rocky.app
Applications -> /Applications
```

## Install UX

1. Download `AgentRocky.dmg`.
2. Open the DMG.
3. Drag `Agent Rocky.app` to Applications.
4. Open the app from Applications, Finder, Spotlight, or Launchpad.

## Signing Modes

First public source release:

- ad-hoc signing is acceptable
- macOS may show Gatekeeper warnings if the user downloads a generated unsigned DMG

Future binary release:

- Developer ID signing
- notarization
- stapled ticket

## Scripts

```text
scripts/package-macos-app.sh
scripts/create-dmg.sh
scripts/build-release.sh
```

`build-release.sh` should build the app bundle, create the DMG, and verify the result.
