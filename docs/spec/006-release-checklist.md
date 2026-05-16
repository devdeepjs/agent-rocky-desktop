# Release Checklist

## Required Checks

```bash
swift test
scripts/build-release.sh
plutil -lint "dist/Agent Rocky.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Agent Rocky.app"
hdiutil verify dist/AgentRocky.dmg
```

## Manual Checks

- Open app from `dist/Agent Rocky.app`.
- Hide panel with the in-app close button.
- Restore panel from menu bar.
- Quit from menu bar.
- Reopen and confirm preferences survive.
- Switch profiles.
- Switch providers.
- Send one message with a configured provider.
- Confirm fallback behavior when provider credentials are missing.

## Public Hygiene

- No private paths in docs.
- No private company references.
- No secrets in repo.
- README starts with install/use, not implementation.
- License is present.
- Screenshots or a demo GIF exist before a polished public announcement.
- Distribution scripts are documented.

## Release Artifacts

- `dist/Agent Rocky.app`
- `dist/AgentRocky.dmg`
