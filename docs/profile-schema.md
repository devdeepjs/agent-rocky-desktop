# Profile Schema

Profiles live in:

```text
~/Library/Application Support/AgentRocky/profiles/
```

Each `.json` file can contain one `CompanionProfile` object or an array of objects. Invalid profiles are ignored.

```json
{
  "id": "tiny-cloud",
  "name": "Tiny Cloud",
  "kind": "custom",
  "systemPrompt": "You are a tiny cloud companion. Be calm, brief, and useful.",
  "defaultModel": null,
  "visualStyle": "cuteBuddy",
  "movementMode": "static",
  "defaultAnimation": "idle",
  "allowedAnimations": ["idle", "wave", "think", "pulse", "happyBounce"],
  "states": {
    "normal": "idle",
    "thinking": "think",
    "idle": ["idle", "wave"],
    "idleCooldownSeconds": 12,
    "idleJitterSeconds": 6,
    "animationAssets": {
      "wave": {
        "kind": "gif",
        "path": "tiny-cloud-wave.gif"
      }
    }
  },
  "idleBehaviors": ["watching", "lookingAround"],
  "accentColorHex": "#99CCFF"
}
```

Current visual styles:

- `cinematicRocky`
- `cartoonCat`
- `cuteBuddy`

Current providers are app settings, not profile settings. A profile can suggest `defaultModel`, but the user can override provider and model from the in-app gear panel.

`states.normal` is the default rendered state. `states.thinking` is used while the provider is working. `states.idle` is the pool of little actions the app picks from occasionally. `idleCooldownSeconds` is the minimum delay between idle actions and `idleJitterSeconds` adds random delay on top.

`animationAssets` is optional. It maps an animation name to an image or GIF. Relative paths are resolved from the profiles directory. Absolute paths and `~/` paths are also supported. If an asset cannot be loaded, the built-in SwiftUI renderer is used.
