# Upgrade Guide

How to move to a newer version of XPENC without losing data, and how to carry
your ledger to a new phone.

## TL;DR

- **Updating in place keeps your data.** Install the new version over the old
  one — the database migrates itself automatically. No reinstall needed.
- **Export a backup first anyway.** *More → Download Data → Export JSON.* One
  minute of insurance.
- **The one thing that wipes data:** installing a build signed with a
  **different key** than the one already on your phone. Android blocks that as an
  update and makes you uninstall first. Match the signing key, or restore your
  backup afterwards.

## How upgrading works

XPENC stores everything in a local database with a **schema version**. When a
new app version introduces schema changes, it ships **migrations** that upgrade
the existing database the first time the new app opens — in place, without
touching your rows.

All migrations to date are **additive** (they only add new, optional columns),
so upgrading is safe and your accounts, transactions, budgets, persons and
settings carry straight over.

You do **not** need to uninstall, and you do **not** need to wipe data, to move
between released versions.

## The one exception: signing keys

Android only allows an install to *update* an existing app if both are signed
with the **same key**. If they differ, Android refuses and the only way to
install is to **uninstall first — which deletes the app's data**.

This bites when you mix sources, for example:

- App installed from **F-Droid** or **Google Play**, then you sideload a
  **self-built or GitHub** APK (different key), or vice-versa.
- A **debug** build over a **release** build.

**How to avoid it:** keep installing from the *same source / same key*. If you
can't, treat it as a phone move: **export a backup, uninstall, install the new
build, then import the backup** (see below).

> Historical note: 1.1.2 changed the per-ABI `versionCode` scheme, so installing
> 1.1.2 over an older sideloaded GitHub APK could require an uninstall. Back up
> before, restore after.

## Always: back up before you upgrade

1. **More → Download Data → Export JSON.**
2. Save/share the file somewhere off the phone (a cloud drive, your computer,
   a chat to yourself).

If anything ever looks wrong after an update, you can reinstall cleanly and
**Import from file** to get everything back.

## Moving to a new phone

XPENC is offline, so there's no cloud sync — you carry your data across as a
file. It's two steps:

1. **Old phone → export.** *More → Download Data → Export JSON* (or *Backup &
   Restore → Back up now*, then share that backup). Send the file to the new
   phone any way you like.
2. **New phone → import.** Install XPENC, then *More → Backup & Restore →
   Import from file* and pick the file. XPENC saves a safety copy of whatever is
   there, then replaces it with your backup.

Everything comes across: accounts, transactions, transfers, budgets, persons and
their dues, your categories (including subcategories), and your currency choice.

The import is **all-or-nothing** — a wrong or corrupt file changes nothing and
explains why, so there's no way to end up with a half-restored ledger.

## Version-specific notes

### Upgrading to 1.2.0

- **Schema:** migrates v4 → v6 automatically (adds a `parentId` for
  subcategories and a `show currency symbol` flag). Both are additive; existing
  data is untouched.
- **After upgrading:** all your current categories are top-level — add
  subcategories whenever you like. Currency stays **INR with the symbol shown**
  until you change it in *Settings → Currency*.
- **No action required** beyond installing, unless the signing-key exception
  above applies to you.

See the [1.2.0 Release Notes](Release-Notes-1.2.0.md) for what's new.
