# Provider Model

## Principle

BYOK means the user can use their own provider and model. The app should support provider-specific clients without making the UI or profile model depend on one vendor.

## Provider Shape

```json
{
  "id": "openai",
  "name": "OpenAI",
  "kind": "cloudAPI",
  "auth": "apiKey",
  "defaultBaseURL": "https://api.openai.com/v1",
  "defaultModel": "gpt-5.4-mini",
  "modelChoices": ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini"],
  "isEnabled": true
}
```

## Initial Providers

- `codex-cli`: local CLI, no API key
- `openai`: OpenAI Responses API
- `openai-compatible`: chat-completions compatible HTTP provider
- `deepseek`: OpenAI-compatible cloud API with DeepSeek defaults
- `gemini`: Google Gemini API
- `ollama`: local Ollama HTTP API

## UI Requirements

Settings must support:

- provider selection
- model dropdown
- custom model text
- base URL for compatible/local providers
- API key where needed
- prompt override
- clear save/reset affordances

## Security

API keys are stored in Keychain under provider-specific accounts. Settings JSON may store provider id, model, prompt, and base URL, but never API keys.

## Honest Availability

The app must not pretend a provider has been tested if it has not. A provider can be listed as configurable, but provider errors must be surfaced clearly and must fall back locally without crashing.

DeepSeek's official OpenAI-compatible base URL is `https://api.deepseek.com`; do not append `/v1`.
