# OCR corrections module — design spec

Date: 2026-08-14
Status: approved, moving to implementation plan

## Background

XPENC's screenshot-capture OCR was switched from Google ML Kit to Tesseract
(`flutter_tesseract_ocr`) to fix F-Droid inclusion (GitHub #57 — ML Kit's
trained-model blobs are non-free even in the bundled, no-Play-Services form;
see `lib/features/message_capture/ocr_service.dart`). That swap is already
shipped as of this doc; this spec is a *separate, additive* feature layered
on top of it.

The original ask was to let users "train an LLM" on their own country's
payment-app screenshots and submit it to improve OCR globally. That premise
doesn't hold: `screenshot_parser.dart` is hand-written regex heuristics, not
a trainable model, and Tesseract's text-recognition step is not something a
phone can usefully fine-tune from a handful of corrections. What actually
varies per app/country is the *parsing* of already-recognized text — which
today already gets updated by hand, one real screenshot at a time (see the
`GitHub #25` citations throughout `screenshot_parser.dart`). This feature
formalizes that existing informal process: a way for users to submit a
labeled example (raw OCR text + what the correct extraction should have
been) for the developer to manually turn into a new parser rule.

## Non-goals

- No on-device model training of any kind.
- No automatic ingestion of submitted corrections into the shipping app —
  every correction is manually reviewed by the developer before it
  influences any parser change.
- No network code added to the app. Corrections leave the device only
  through the user's own share sheet / mail app, exactly like existing
  backup/export flows.

## Privacy constraint (load-bearing)

XPENC's privacy policy states release builds do not request the `INTERNET`
permission and are "technically incapable of transmitting your data
anywhere." This feature must not weaken that claim:

- The app's own code never makes a network call.
- Sending a correction is done by handing text to an external app via an
  Android intent (`mailto:` or the OS share sheet) — the same mechanism
  already used and disclosed for JSON/CSV backup exports.
- Only extracted/corrected **text** is included. The source screenshot
  image is never attached or transmitted.
- The feature is entirely opt-in: nothing is captured unless the user
  deliberately opens the screen, and nothing is sent unless the user
  deliberately taps send.

`privacy.html` needs a new section, modeled on the existing "Backups and
exports" section, disclosing this optional flow. This is additive, not a
retraction of the "technically incapable" claim (no `INTERNET` permission
is added). Play Data Safety very likely doesn't need to change either,
since Play's form tracks data the app's own code collects/shares, not data
a user manually exports via an OS share intent — worth a quick sanity check
against current Play guidance before release, not expected to be an issue.

## Data model

New Drift table `OcrCorrections` (schema v29 → v30), following the existing
typed-column convention in `lib/data/tables.dart` (no JSON blob columns):

| column | type | notes |
|---|---|---|
| id | int, PK autoincrement | |
| createdAt | DateTime | |
| appLabel | text | "Google Pay" / "PhonePe" / "Samsung Pay" / "WhatsApp Pay" / free text |
| country | text, nullable | free text |
| rawOcrText | text | verbatim Tesseract output |
| wasCorrect | bool | true = parser got it right as-is |
| extractedAmount / extractedDirection / extractedPayee / extractedReference | text, nullable | what `ScreenshotParser` produced |
| correctedAmount / correctedDirection / correctedPayee / correctedReference | text, nullable | only set when `wasCorrect == false` |
| sentAt | DateTime, nullable | null = still queued; set when a send intent is fired |

`AppDatabase` gains methods in the existing house style (no separate
repository class): `addOcrCorrection(...)`, `watchPendingOcrCorrections()`,
`markOcrCorrectionsSent(List<int> ids)`, `deleteOcrCorrection(int id)`.

## UI flow

New module: `lib/features/message_capture/ocr_feedback/` (sits next to the
existing capture code since it reuses `OcrService` and `ScreenshotParser`
directly — a test screenshot goes through the exact same pipeline a real
capture would, so what the user sees while testing matches production).

**Entry point:** Settings → Message Capture section → new row "OCR
corrections", pushing `/more/capture/ocr-feedback`.

**List screen** (`OcrCorrectionScreen`):
- Explanation callout at the top: optional, on-device, only text ever
  leaves and only when the user taps send, image never included.
- Pending corrections listed (swipe-to-delete via `flutter_slidable`,
  matching `transactions_screen.dart`'s existing pattern); each row shows
  app label, a snippet of raw OCR text, and a correct/incorrect badge.
- Sent corrections shown collapsed below, kept for the user's own record,
  not re-sendable.
- "+ Test a screenshot" button/FAB.
- "Send N corrections" bar, visible once ≥1 correction is pending.

**Capture sub-flow** (new correction):
1. `file_picker` image pick (existing dependency).
2. Run `OcrService.recognizeText` then `ScreenshotParser.parse` — identical
   pipeline to real capture.
3. Show raw OCR text (read-only) and the four extracted fields as editable
   text inputs, pre-filled with what the parser produced.
4. App-label chips (Google Pay / PhonePe / Samsung Pay / WhatsApp Pay /
   Other) + a free-text country field.
5. Two actions: "This is correct" (saves as-is, `wasCorrect = true`,
   corrected* fields null) or "This is wrong — let me fix it" (unlocks the
   fields for editing, saves `wasCorrect = false` plus the corrected
   values).
6. If OCR returns no text at all, the fields stay empty and the user can
   still fill them in manually and save — a legitimate signal ("OCR found
   nothing on this screen") worth capturing.

## Transport

Tapping "Send N corrections" builds a JSON array of the pending rows:

```json
[
  {
    "appLabel": "PhonePe",
    "country": "India",
    "rawOcrText": "Payment successful\n₹500\nTo John Doe\n...",
    "wasCorrect": false,
    "extracted": {"amount": "500", "direction": "debit", "payee": "John Doe", "reference": null},
    "corrected": {"amount": "500", "direction": "debit", "payee": "John D.", "reference": "123456789012"}
  }
]
```

plus a top-level `appVersion` (from `AppInfo.version`) so submissions can be
matched to the parser version that produced the "extracted" side.

Send logic:
1. If the encoded body is under ~1500 characters, try a `mailto:` link
   (via `url_launcher`, already used for the About screen's external
   links) pre-addressed to `AppInfo.feedbackEmail` (`feedback.yashpatil@gmail.com`
   — the existing non-personal feedback inbox, reused rather than adding a
   new address), subject `XPENC OCR corrections (N)`, body = pretty-printed
   JSON.
2. If the body is too large for a safe `mailto:`, or no mail handler
   answers, fall back to the OS share sheet (`share_plus`, same mechanism
   already used for backup exports) with the JSON as shared text, and UI
   copy reminding the user to send it to `AppInfo.feedbackEmail`.
3. Once an intent is fired (either path), mark the included rows'
   `sentAt` to now. No delivery confirmation is possible or attempted —
   same honesty the app's existing export flows already have.

## Error handling

- No mail app and no share target available at all: SnackBar explaining
  nothing could be sent; corrections remain queued untouched.
- Deleting a queued correction is immediate, no confirmation dialog
  (low-stakes, unlike "Clear all data").

## Testing

- Unit tests for the new `AppDatabase` methods (add / list pending / mark
  sent / delete).
- Widget test for `OcrCorrectionScreen`: empty state, add-and-list flow
  using a fake `OcrService` (same `_FakeOcr` pattern already used in
  `test/screenshot_intake_test.dart`), and that sending builds the
  expected JSON shape and marks rows sent.
- OCR accuracy itself is not something a widget test can verify — that
  stays a manual, on-device check.

## Documentation updates

- `privacy.html`: new "OCR corrections (optional)" section modeled on the
  existing "Backups and exports" section; bump the effective date.
- `CHANGELOG.md`: note the new feature and the privacy-policy update, per
  the policy's own "Changes to this policy" commitment.
