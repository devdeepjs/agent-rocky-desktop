# Profile Model

## Principle

A companion profile is data. The app can ship bundled profiles, and later it can load user profiles from JSON.

## Shape

```json
{
  "id": "orange-cat",
  "name": "Orange Cat",
  "kind": "cat",
  "systemPrompt": "You are a tiny orange desk cat companion...",
  "defaultProviderID": "openai",
  "defaultModel": "gpt-5.4-mini",
  "visualStyle": "cartoonCat",
  "movementMode": "static",
  "accentColorHex": "#FFB35C",
  "states": {
    "normal": "idle",
    "thinking": "workInPlace",
    "idle": ["sleep", "lick", "play"],
    "idleCooldownSeconds": 12,
    "idleJitterSeconds": 8,
    "animationAssets": {
      "sleep": {
        "kind": "gif",
        "path": "cat-sleep.gif"
      }
    }
  },
  "allowedAnimations": ["idle", "sleep", "lick", "purr", "play", "excited"]
}
```

## Required Fields

- `id`
- `name`
- `kind`
- `systemPrompt`
- `visualStyle`
- `movementMode`
- `accentColorHex`
- `states.normal`
- `states.thinking`
- `states.idle`
- `states.idleCooldownSeconds`
- `states.idleJitterSeconds`
- `allowedAnimations`

## Three Visual States

Every profile must support:

- `normal`: default visible state
- `thinking`: active work state while the model/provider is running
- `idle`: small random actions when the user is not interacting

Idle actions run after `idleCooldownSeconds` plus a random `idleJitterSeconds` window. That keeps different profiles from feeling robotic.

## GIF / Asset Support

Image and GIF support maps into the same state model:

```json
{
  "animationAssets": {
    "idle": {
      "kind": "image",
      "path": "normal.png"
    },
    "think": {
      "kind": "gif",
      "path": "thinking.gif"
    }
  }
}
```

If an asset path cannot be loaded, the app falls back to the built-in SwiftUI renderer for that profile.
