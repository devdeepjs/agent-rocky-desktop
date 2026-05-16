# Architecture

## Principle

Rocky is a bundled profile. Codex is a bundled provider. Neither is the platform.

## Current Module Layout

```text
Sources/AgentRocky/
  App/
    FloatingPanelController.swift
    main.swift
  Domain/
    BrainModels.swift
  Brain/
    BrainService.swift
  Profiles/
    BundledProfiles.swift
  Persistence/
    ConversationStore.swift
    KeychainSecretStore.swift
  UI/
    RootView.swift
    CompanionAppViewModel.swift
```

## Brain Flow

```text
Terminal input
  -> CompanionAppViewModel
  -> BrainService
  -> selected BrainClient
  -> BrainResponse JSON
  -> profile validation
  -> companion state update
  -> ConversationStore persistence
```

## Provider Boundary

Every provider path returns one app contract:

```swift
func respond(...) async -> BrainResult
```

Provider-specific request shape, auth headers, response parsing, CLI invocation, and base URL handling stay inside `BrainService`. If this file grows further, split it into provider clients without changing the UI contract.

## Profile Boundary

Profiles define available behavior. Renderers display behavior. The brain can suggest a state or animation, but profile validation decides what is allowed.

## Persistence Boundary

Conversation history, preferences, and secrets are separate:

- conversations: JSON files in Application Support
- preferences: JSON settings in Application Support
- secrets: macOS Keychain

No API key should be written to conversation or settings JSON.
