# Category templates — design spec

Date: 2026-09-06
Status: implemented
GitHub: #101

## Background

serrq's ask (#101): save the current category/sub-category structure as a
reusable template, and switch between templates without losing the history of
already-categorized transactions. Explicitly orthogonal to Ready to Assign —
this is about which categories exist, not how money is allocated to them.

## Why the existing archive rule makes this easy

`Categories` already never hard-deletes — `AppDatabase.archiveCategory`'s own
doc comment says why: "deleting a category orphans every past transaction
that referenced it." Every transaction stores a `categoryId` pointing at a
live `Categories` row, archived or not.

That means "switch template" doesn't need to touch a single `Transactions`
row. It only needs to change which `Categories` rows are archived vs. active:

- A category in the *target* template but not currently active → created (or
  unarchived + relabelled, if a same-named one already exists).
- A category currently active but not in the *target* template → archived.
  Every transaction that used it keeps pointing at the same (now-archived)
  row, so reports and statements are untouched.

Switching back later re-activates the old set the same way — nothing was
ever deleted, so it's a free "revert."

## Data model

Two new tables, independent of `Categories`:

- `CategoryTemplates` (id, name, createdAt) — one row per saved template.
- `CategoryTemplateItems` (id, templateId, name, kind, colorValue, iconKey,
  sortOrder, parentItemId) — a template's own category tree, exactly two
  levels deep like `Categories.parentId`, but `parentItemId` resolves against
  *other rows in the same template*, not live category ids. A template must
  be applicable on a fresh install that has never seen these categories.

## Matching: how "switch" maps template items onto live categories

Live categories and template items are matched by
`(kind, name.trim().toLowerCase(), parentName.trim().toLowerCase())` — not by
id, since a template's ids are meaningless outside the template that made
them. Two categories are "the same" if they have the same kind, name, and
parent name.

`applyCategoryTemplate`:
1. Load the target template's items, parents before children.
2. For each parent item: if a live top-level category matches, relabel it
   (name/colour/icon) in place and record the match; otherwise create one.
3. For each child item: same, nested under the (matched-or-created) live
   parent from step 2.
4. Any currently-active category (parent or child) that wasn't matched gets
   archived — its transactions keep it, just hidden from new entries, same
   as a manual archive.

Re-nesting a live category that itself still has children (the two-level
cap in `updateCategory`) can throw; `applyCategoryTemplate` catches that one
case and keeps the category's existing parent rather than aborting the whole
switch, so one awkward re-nest never blocks everything else in the template.

## Non-goals (v1)

- No community/shared template gallery — save/switch only, all local.
- Templates aren't part of `exportAll`/`importAll` in this pass; they are a
  local convenience over `Categories`, not part of the ledger itself, so a
  ledger backup doesn't need to carry them for now. Revisit if requested.
- No automatic re-run of budgets when a template switch archives a budgeted
  category — `Budgets` already handles an archived category's row the same
  way manual archiving does today.
