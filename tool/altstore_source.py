#!/usr/bin/env python3
"""Write XPENC's AltStore / SideStore source for one release.

    python3 tool/altstore_source.py --app build/ios/iphoneos/Runner.app \\
        --ipa release/xpenc-ios.ipa --tag v1.6.4 --out release/xpenc-altsource.json

One file serves both stores: SideStore reads AltStore's source format (an
"AltSource"). People add https://xpenc.in/ios/source.json, which
website/vercel.json redirects to the copy of this file on the latest GitHub
Release — so publishing a release is all an update takes.

Nothing about the build is typed by hand. AltStore refuses to install an app
whose permissions don't match what its source declares, and both stores check
the version and build number against the download, so all of those are read
off the built app itself.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

REPO = "PATILYASHH/XPENC"
SOURCE_URL = "https://xpenc.in/ios/source.json"
IPA_ASSET = "xpenc-ios.ipa"

# Always present, and AltStore says not to list them.
IMPLICIT_ENTITLEMENTS = {
    "application-identifier",
    "com.apple.developer.team-identifier",
}

# Long sections get cut here, with a link to the full CHANGELOG.
NOTES_LIMIT = 2500

# iPhone screenshots, in listing order. Captured on a 6.9" iPhone Simulator
# by .github/workflows/ios-screenshots.yml and served by the website from
# website/assets/ios/<name>.jpg.
SCREENSHOTS = [
    "06-glass-dashboard",
    "01-dashboard",
    "02-transactions",
    "03-add-expense",
    "04-persons",
    "05-budgets",
    "07-glass-transactions",
]
SCREENSHOT_URL = "https://xpenc.in/assets/ios/{}.jpg"
SCREENSHOT_SIZE = (1320, 2868)


def info_plist(bundle: Path) -> dict:
    with open(bundle / "Info.plist", "rb") as f:
        return plistlib.load(f)


def privacy(app: Path) -> dict[str, str]:
    """Every `…UsageDescription` the app and its extensions declare."""
    found: dict[str, str] = {}
    for bundle in [app, *sorted((app / "PlugIns").glob("*.appex"))]:
        for key, value in info_plist(bundle).items():
            if key.endswith("UsageDescription"):
                found[key] = value
    return dict(sorted(found.items()))


def entitlements(app: Path) -> list[str]:
    """What the binary is signed with — nothing, for the unsigned CI build."""
    try:
        out = subprocess.run(
            ["codesign", "-d", "--entitlements", "-", "--xml", str(app)],
            capture_output=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return []  # not signed at all, or not on macOS
    if not out.strip():
        return []
    return sorted(set(plistlib.loads(out)) - IMPLICIT_ENTITLEMENTS)


def release_notes(changelog: Path, version: str) -> str:
    """This version's CHANGELOG section, as plain text."""
    text = changelog.read_text(encoding="utf-8")
    match = re.search(
        rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)",
        text,
        flags=re.S | re.M,
    )
    if not match:
        return ""
    notes = match.group(1).strip()
    notes = re.sub(r"\*\*(.+?)\*\*", r"\1", notes, flags=re.S)  # bold
    notes = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", notes)  # links
    notes = re.sub(r"`([^`]+)`", r"\1", notes)  # code
    notes = re.sub(r"^### ", "", notes, flags=re.M)  # headings
    notes = re.sub(r"\n{3,}", "\n\n", notes)
    if len(notes) > NOTES_LIMIT:
        # At the last whole bullet (or paragraph) that fits, not mid-sentence.
        cut = max(notes.rfind("\n- ", 0, NOTES_LIMIT), notes.rfind("\n\n", 0, NOTES_LIMIT))
        notes = notes[: cut if cut > 0 else NOTES_LIMIT].rstrip()
        notes += (
            "\n\n…and more: "
            f"https://github.com/{REPO}/blob/master/CHANGELOG.md"
        )
    return notes


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_source(app: Path, ipa: Path, tag: str, changelog: Path, date: str) -> dict:
    info = info_plist(app)
    version = info["CFBundleShortVersionString"]
    build = str(info["CFBundleVersion"])
    if tag.removeprefix("v") != version:
        raise SystemExit(f"Tag {tag} does not match the app's version {version}.")

    download_url = f"https://github.com/{REPO}/releases/download/{tag}/{IPA_ASSET}"
    size = ipa.stat().st_size
    notes = release_notes(changelog, version)

    return {
        "name": "XPENC",
        # SideStore before 0.6 keys a source by this; newer SideStore and
        # AltStore use the source URL. Never change it.
        "identifier": "com.yash.xpenc.source",
        "sourceURL": SOURCE_URL,
        "subtitle": "Money, tracked honestly.",
        "description": (
            "The official source for XPENC, a free, open-source, offline-first "
            "expense tracker and budget app."
        ),
        "iconURL": "https://xpenc.in/assets/xpenc_icon_512.png",
        "website": "https://xpenc.in",
        "tintColor": "#2563EB",
        "apps": [
            {
                "name": "XPENC",
                "bundleIdentifier": info["CFBundleIdentifier"],
                "developerName": "Yash Patil",
                "subtitle": "Money, tracked honestly.",
                "localizedDescription": (
                    "XPENC is a free, open-source, offline-first expense tracker "
                    "and budget app. Track income, expenses, budgets, savings "
                    "goals, dues and loans — everything stays on your iPhone. No "
                    "server, no sign-up, no ads.\n\n"
                    "This is the first iOS build. A few Android features aren't "
                    "here yet: home screen widgets, sharing into XPENC, reading "
                    "payment screenshots, and blocking screenshots.\n\n"
                    "Backups are kept inside XPENC, so deleting the app deletes "
                    "them too — share a backup to Files or iCloud Drive to keep "
                    "a copy.\n\n"
                    f"Source code: https://github.com/{REPO}"
                ),
                "iconURL": "https://xpenc.in/assets/xpenc_icon_512.png",
                "tintColor": "#2563EB",
                "category": "utilities",
                "screenshots": [
                    {
                        "imageURL": SCREENSHOT_URL.format(name),
                        "width": SCREENSHOT_SIZE[0],
                        "height": SCREENSHOT_SIZE[1],
                    }
                    for name in SCREENSHOTS
                ],
                "versions": [
                    {
                        "version": version,
                        "buildVersion": build,
                        "date": date,
                        "localizedDescription": notes,
                        "downloadURL": download_url,
                        "size": size,
                        "sha256": sha256(ipa),
                        "minOSVersion": info.get("MinimumOSVersion", "15.0"),
                    }
                ],
                "appPermissions": {
                    "entitlements": entitlements(app),
                    "privacy": privacy(app),
                },
                # Pre-"versions" clients (old SideStore) read these instead.
                "screenshotURLs": [SCREENSHOT_URL.format(n) for n in SCREENSHOTS],
                "version": version,
                "versionDate": date,
                "versionDescription": notes,
                "downloadURL": download_url,
                "size": size,
            }
        ],
        "news": [],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--app", type=Path, required=True, help="the built Runner.app")
    parser.add_argument("--ipa", type=Path, required=True, help="the packaged .ipa")
    parser.add_argument("--tag", required=True, help="the release tag, e.g. v1.6.4")
    parser.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    parser.add_argument(
        "--date",
        default=datetime.now(timezone.utc).date().isoformat(),
        help="release date, ISO 8601 (default: today, UTC)",
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    source = build_source(args.app, args.ipa, args.tag, args.changelog, args.date)
    args.out.write_text(
        json.dumps(source, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    app = source["apps"][0]
    print(f"Wrote {args.out}: XPENC {app['version']} ({app['versions'][0]['buildVersion']})")
    print(json.dumps(app["appPermissions"], indent=2))


if __name__ == "__main__":
    main()
