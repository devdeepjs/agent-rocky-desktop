# Product Contract

## Product

Agent Rocky is a local macOS desktop companion platform. It ships with a few bundled companion profiles, but the app architecture must not be hardcoded around Rocky, Codex, or any one model provider.

## User Experience

The app must feel like a normal macOS app:

- a downloadable DMG is the release artifact
- the DMG contains `Agent Rocky.app` and an Applications shortcut
- the app can be opened from Finder, Launchpad, or Applications
- the floating companion can be hidden without quitting
- the menu-bar item can restore or quit the app
- settings are configurable inside the app

## Core Concepts

- A companion profile defines personality, prompt, visual renderer, allowed actions, and state behavior.
- A brain provider defines how a model is called.
- A conversation stores local chat history and provider session metadata.
- App preferences store the selected provider, model, base URL, prompt override, and selected profile.

## Non-Goals For First Public Push

- App Store distribution
- Apple Developer notarization
- paid binary distribution
- launch-at-login
- cloud account sync
- full custom profile editor with validation UI
- full GIF asset pack editor

## Public Push Bar

The repo is pushable when a fresh developer can clone it, read the README, build a DMG, open the app, configure a provider, and understand the architecture without private context.
