# Handoff

**A fast, native mobile client for [OpenHands Cloud](https://app.all-hands.dev).**

OpenHands Cloud runs coding agents in a sandbox and exposes a web UI (Canvas). On a
phone that UI is awkward, and it has three problems that make it unusable for
long-running work:

1. **The agent seems to stop when you leave the page.** The web client ties its
   WebSocket to the conversation view, so navigating away drops the connection.
   (The agent itself keeps running on the server — it is a client-side bug.)
2. **The conversation history reloads over and over.** There is no local cache,
   so every visit refetches the transcript from the network.
3. **No notifications.** Nothing tells you when the agent finished or is waiting
   for your answer.

Handoff is a from-scratch Flutter client built around those three fixes.

> Handoff is an independent, unofficial client. It is not affiliated with or
> endorsed by All Hands AI.

## What it does differently

| Problem | How Handoff fixes it |
| --- | --- |
| Agent "stops" on navigation | One **global session service** owns the WebSocket for the whole app lifetime. Screens subscribe to it; leaving a screen never closes the socket. |
| History reloads repeatedly | Events are **cached on disk** per conversation, so the transcript paints instantly and only new events come over the network. |
| No notifications | **Native notifications** on the transitions that matter: needs input, needs confirmation, finished, error. |
| Lost events after a disconnect | The socket resumes with the server's `after_seq` cursor, so a reconnect replays exactly what was missed. |

## Requirements

- Flutter 3.50 or newer (Dart 3.14+)
- An OpenHands Cloud account
- Android 7.0 (API 24) or newer on the device

## Building

The released APK targets **ARM64 (`arm64-v8a`) only** for now, so a single file
installs on essentially every Android phone. Other ABIs (and iOS) come later.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The result is `build/app/outputs/flutter-apk/app-release.apk`.

### Release signing

Release builds are signed with a keystore that is **not** in this repository.
Create `android/key.properties` and a keystore next to it:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=aivos
storeFile=aivos-release.jks
```

```bash
keytool -genkeypair -v -keystore android/aivos-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias aivos
```

Without `key.properties` the build falls back to debug signing, which is fine for
local testing but must not be published.

## Signing in

Handoff uses the OAuth **device flow** (RFC 8628), so no password is ever typed
into or stored by the app:

1. Tap *Sign in with Cloud*. The app shows a short code.
2. Tap *Open the sign-in page* and approve the request in your browser.
3. The app picks up the token and stores it in the platform keystore.

## How it talks to OpenHands

```
Handoff (Flutter)
  │
  ├─ HTTPS  app.all-hands.dev/api/v1/...        list/create conversations
  │         oauth/device/...                    sign-in
  │
  └─ HTTPS/WSS  <sandbox>.prod-runtime.all-hands.dev
                X-Session-API-Key: <session key>   live events, messages, control
```

Account-level calls use the bearer token. Each conversation record carries a
`conversation_url` and a `session_api_key`, which is everything needed to talk
straight to that conversation's sandbox agent server — REST for history and
actions, a WebSocket for live events.

## Project layout

```
lib/
  config/      static configuration (hosts, paths, sizes)
  models/      conversation, event, and agent-state types
  providers/   Riverpod providers; singletons live for the app's lifetime
  screens/     login, conversation list, transcript, new task
  services/    device flow, Cloud API, agent server client, session, cache,
               notifications, secure token storage
  widgets/     transcript rendering
test/          unit tests for models and the on-disk cache
```

The interesting file is `lib/services/session_service.dart`: it is where the
"keep the agent alive across navigation" behaviour actually lives.

## Development

```bash
flutter analyze
flutter test
```

## Status

Early. Android is the only target so far, and the released APK is ARM64-only.

Planned: other Android ABIs, iOS, richer action rendering (diffs, terminal),
and a foreground service so long tasks survive the app being backgrounded.

## Licence

MIT. See [LICENSE](LICENSE).
