# exosynk_ai — Exo

**Exo** is the one assistant across ExoSynk Labs apps. Instead of every app
naming and describing its AI differently, they all share this package:

- **Who Exo is**: name, maker, where feedback goes (`Exo`).
- **What Exo knows about ExoSynk Labs**: every app, in a sentence or two
  (`exoApps`).
- **How Exo behaves everywhere**: read-only, never invents facts, no
  investment/tax/legal/medical advice, brief (`ExoKnowledge.sharedRules`).
- **What it says about itself**: a short FAQ, so a small on-device model
  answers "who made you?" from facts, not imagination (`ExoKnowledge.faq`).

An app adds only its own part — its rules and its data — and builds its
prompt with `ExoKnowledge.about(currentAppId: 'xpenc')`.

Pure Dart, no Flutter, no network. It lives in the XPENC repo for now; when a
second app ships Exo, move it to its own repository (e.g.
`github.com/ExoSynkLabs/exo`) and depend on it from both, so there stays one
copy of every fact.

A build may hide an app it must not promote (XPENC's F-Droid build hides
CONECTR): pass it in `hiddenApps`.
