<div align="center">

<img src="assets/app_icon.png" alt="Handoff" width="112" />

# Handoff

**A clean OpenHands client for your phone.**

Sign in, pick up your conversations, and let the Guard keep them alive.

<p>
  <a href="https://github.com/ferelking242/handoff/releases/latest"><img src="https://img.shields.io/github/v/release/ferelking242/handoff?style=flat-square&amp;label=release" alt="Latest release" /></a>
  <a href="https://github.com/ferelking242/handoff/actions/workflows/build-handoff-apk.yml"><img src="https://img.shields.io/github/actions/workflow/status/ferelking242/handoff/build-handoff-apk.yml?style=flat-square&amp;label=build" alt="Build" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/ferelking242/handoff?style=flat-square" alt="License" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/built%20with-Flutter-02569B?style=flat-square&amp;logo=flutter&amp;logoColor=white" alt="Built with Flutter" /></a>
</p>

</div>

## What this is

Handoff is the phone side of an OpenHands setup. The conversations, the
animation and the whole interface come from [Kelivo](https://github.com/Chevey339/kelivo),
which does the UI very well. The model plumbing Kelivo brings — provider keys,
model catalogues, local inference, tools, MCP, scheduled tasks — is gone. What
is left is a client that talks to OpenHands and nothing else.

Sign-in is OAuth against your OpenHands account, the same way the web app does
it. No API key to paste, no provider to configure.

## Download

Grab the latest APK from the [releases page](https://github.com/ferelking242/handoff/releases/latest).
It is built for **64-bit ARM only** (`arm64-v8a`), which covers every phone made
since roughly 2017.

On the phone, open the file and allow installing from unknown sources.

## The Guard

Notifications come from [handoff-guard](https://github.com/ferelking242/handoff-guard),
a small service you run yourself. It watches your conversations, nudges an agent
that has gone quiet, and pushes a notification when one finishes.

Set the address in the app, or bake it in at build time so the phone finds it on
first launch:

```bash
flutter build apk --release \
  --target-platform android-arm64 \
  --dart-define=HANDOFF_GUARD_URL=https://your-vps:8000 \
  --dart-define=HANDOFF_GUARD_KEY=your-guard-key
```

## Building from source

```bash
flutter pub get
flutter analyze lib
flutter build apk --release --target-platform android-arm64
```

The APK is unsigned unless you provide `android/key.properties` pointing at a
keystore. The CI workflow restores one from repository secrets and refuses to
upload an artifact it could not verify.

## What was removed

Everything that talked to a model directly. The interface, the conversation
storage, the animations, the theming and the settings screens stay. If you want
the full Kelivo feature set, use [Kelivo](https://github.com/Chevey339/kelivo) —
it is very good at what it does.

## Licence

Inherited from Kelivo. See [LICENSE](LICENSE). The upstream project and its
contributors did the hard part; this is a cut-down client built on their work.
