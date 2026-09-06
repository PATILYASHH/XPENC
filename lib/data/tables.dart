import 'package:drift/drift.dart';

import '../core/money.dart';

// ─── Enums ──────────────────────────────────────────────────────────────────

/// Where money sits. Only Cash, Bank, *credit* Card, Pay-later and Prepaid
/// Balance hold a real balance.
///
/// [payLater] is a BNPL-style credit line (Simpl, LazyPay, Amazon Pay Later,
/// …): spending it goes negative exactly like a credit card, and a payment
/// posts as a transfer into it — but it is never a physical card, so it gets
/// its own type rather than a third [CardKind].
///
/// [prepaidBalance] is a closed-loop stored-value instrument (a canteen key
/// fob, a gift card, a transit card, …): unlike [payLater] it is **not** a
/// liability — spending it draws down a real balance you already loaded,
/// exactly like [cash] or [bank]. It gets its own type only so it can carry
/// its own icon/label; every balance and net-worth code path treats it
/// identically to [cash]/[bank] with no special-casing.
///
/// [goal] is a savings target that holds its own real balance, exactly like
/// [prepaidBalance] — see [GoalDetails]. Funded and drawn down only by a
/// [TxType.transfer] to/from another account, same as every other account.
///
/// [loan] is a liability account — [openingBalance]/[currentBalance] are both
/// negative (the principal borrowed), moving toward zero as payments post via
/// [TxType.transfer] into the loan account. See [LoanDetails].
enum AccountType { cash, bank, card, payLater, prepaidBalance, goal, loan }

/// A credit card is its own (liability) account. A debit card is an instrument
/// linked to a bank — it never holds its own balance.
enum CardKind { credit, debit }

enum CategoryKind { income, expense }

/// A transfer is neither income nor expense. It must never appear in budgets
/// or income/expense reports.
///
/// [personOut] / [personIn] move real money to and from a person. Lending is
/// not spending and being repaid is not earning, so these are excluded from
/// income/expense totals and budgets exactly like a transfer — but they DO move
/// the account balance, and they appear in the ledger so the money is never
/// seen to vanish.
enum TxType { income, expense, transfer, personOut, personIn }

extension TxTypeX on TxType {
  /// Only these two ever count toward income, expense, budgets and reports.
  bool get isIncomeOrExpense => this == TxType.income || this == TxType.expense;

  bool get isPersonMovement =>
      this == TxType.personOut || this == TxType.personIn;

  /// Does this add to the account it names, or take from it?
  bool get addsToAccount => this == TxType.income || this == TxType.personIn;
}

enum BudgetPeriod { weekly, monthly, yearly }

/// `+` = they owe you (receivable). `-` = you owe them (payable).
enum PersonDirection { theyOwe, iOwe }

enum ReminderDirection { pay, receive }

enum ReminderRepeat { none, weekly, monthly, yearly }

enum ReminderStatus { open, done, snoozed, dismissed }

/// Where a captured message came from. The parser is source-agnostic so a
/// notification listener can be swapped in without touching anything else.
/// `shared`: the user picked XPENC from the Android Share sheet on a
/// message from their SMS/bank app — see `share_intake.dart` and GitHub
/// #26. `screenshot`: the user shared a payment-app screenshot (PhonePe/
/// GPay/Paytm "payment successful" screen) instead of text — the image is
/// OCR'd on-device and the recognised text is parsed by `ScreenshotParser`
/// exactly like a shared SMS is by `MessageParser` — see
/// `parser/screenshot_parser.dart` and GitHub #25. A `textEnum` column, so
/// adding either of these needed no migration.
enum MessageSourceKind { sms, notification, shared, screenshot }

/// Banking sense: `debit` = money out, `credit` = money in.
/// (Distinct from a *credit card*, which is an account.)
enum TxDirection { debit, credit }

enum PendingStatus { pending, autoFilled, approved, dismissed, duplicate }

/// Which budget alert already fired this period, so we never spam.
enum AlertLevel { threshold, overspent }

/// How often a recurring rule fires. Daily/weekly/biweekly need no separate
/// "which day" field — the day is implied by whatever date the rule's
/// `nextDueDate` already carries; only monthly additionally pins
/// [RecurringRules.dayOfMonth] so a short month can snap back to the
/// intended day the following month instead of drifting.
enum RecurringFrequency { daily, weekly, biweekly, monthly }

/// How often automatic backups run. `custom` ignores the fixed cadences and
/// uses [Settings.autoBackupCustomDays] + [Settings.autoBackupCustomHours]
/// instead.
enum AutoBackupFrequency { daily, monthly, custom }

/// Which numpad the lock screen (and the set/change-passcode screen) draws
/// (GitHub #81). `classic` is plain text digits, no button background —
/// XPENC's original look. `bigNumpad` is large filled circular buttons in
/// the usual 1-9,0 order, easier to hit and to read at a glance. `scrambled`
/// is the same big buttons with their digits reshuffled into random
/// positions on every fresh attempt, so a shoulder-surfer watching finger
/// position can't infer the PIN.
enum LockScreenStyle { classic, bigNumpad, scrambled }

/// Which credential(s) the app's active front-door lock requires. Originally
/// (GitHub #104) the user picked exactly one, never a combination — that
/// changed with the addition of [pinAndTotp] (GitHub #111): a true two-factor
/// front door requiring *both* a correct PIN and a correct authenticator code,
/// entered one after the other, rather than either alone. `hasUnlockCredential`
/// in `core/security/unlock_method.dart` maps this to whether the credential(s)
/// it needs are actually configured; [Settings.masterPhraseHash] can still be
/// set and used purely as a fallback (see
/// [Settings.masterPhraseAttemptThreshold]) while a different method is
/// active.
enum UnlockMethod { pin, masterPhrase, totp, pinAndTotp }

/// How the More hub (`MoreScreen`) lays out its items. `list` is the
/// original one-column row layout. `cards` shows two square-ish cards per
/// row instead, still grouped the same way.
enum MoreScreenViewMode { list, cards }

/// Legacy — superseded by `Settings.rtaEnabled` (GitHub #100 v2). Budget
/// (the per-category ceiling system) is now always on for everyone, and
/// Ready to Assign is a single on/off layer on top of it rather than a
/// mutually-exclusive alternative. This enum/column is kept only so the
/// `from < 62` migration can read a pre-existing user's choice once, to
/// decide whether to backfill `rtaEnabled = true` — nothing writes to it
/// anymore.
enum BudgetingMode { budgets, envelope }

// ─── Converters ─────────────────────────────────────────────────────────────

/// Money crosses the DB boundary as an integer number of paise. Never a double.
class MoneyConverter extends TypeConverter<Money, int> {
  const MoneyConverter();

  @override
  Money fromSql(int fromDb) => Money(fromDb);

  @override
  int toSql(Money value) => value.paise;
}

/// A manually-entered exchange rate: how many units of the parent currency
/// (`Settings.currencyCode`) equal one unit of some other currency, as of a
/// given date. Never fetched live — see the design spec's "Non-goals".
///
/// Rows accumulate as history; adding a new rate is always an insert, never
/// an update, so a transaction posted under an old rate stays resolvable
/// (`AppDatabase.latestRate`) even after the rate moves on. This is what
/// makes converted historical totals stable when the rate changes later.
@DataClassName('CurrencyRateRow')
class CurrencyRates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The non-parent currency this rate prices, e.g. `USD`. Never the parent
  /// currency itself, which is always 1:1 with itself.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  /// Units of the parent currency per 1 unit of [currencyCode], scaled by
  /// [currencyRateScale] so it's an exact integer — never a `double`, the
  /// same rule [Money] follows. `83_120_000` means 1 unit = 83.12 parent.
  IntColumn get rateToBaseMicros => integer()();

  DateTimeColumn get effectiveAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ─── Tables ─────────────────────────────────────────────────────────────────

@DataClassName('AccountRow')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => textEnum<AccountType>()();

  /// Only set when [type] is [AccountType.card].
  TextColumn get cardKind => textEnum<CardKind>().nullable()();

  /// Set for debit cards (and UPI-style instruments): the bank they draw from.
  /// When non-null this account holds **no** balance of its own.
  IntColumn get linkedAccountId =>
      integer().nullable().references(Accounts, #id)();

  /// For message auto-capture: which bank, and the last 4 digits to match on.
  TextColumn get bankName => text().nullable()();
  TextColumn get last4 => text().withLength(min: 4, max: 4).nullable()();

  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().withLength(min: 1, max: 40)();

  IntColumn get openingBalance => integer().map(const MoneyConverter())();

  /// Cache of the ledger. Updated atomically with every write.
  /// `recalculateBalances()` rebuilds it from the ledger if it ever drifts.
  IntColumn get currentBalance => integer().map(const MoneyConverter())();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Whether this account is "on-budget" — inside the shared Ready to
  /// Assign pool — rather than off-budget/tracking-only (a balance-only
  /// account, outside the pool, like a vending-machine key fob). Only
  /// meaningful while `Settings.rtaEnabled` is on: turning RTA on globally
  /// sets this to true for every account at once, and turning it off for
  /// the last pool account while RTA is on turns RTA off automatically
  /// (see `AppDatabase.setRtaEnabled` / `_maybeAutoDisableRta`). An
  /// on-budget account's expenses are funded from the pool via
  /// [Allocations] — see `categoryBalanceProvider` / `readyToAssignProvider`
  /// in `data/providers.dart`.
  BoolColumn get envelopeMode => boolean().withDefault(const Constant(false))();

  /// Whether this account's balance counts toward Net Worth (dashboard,
  /// Accounts screen total, More screen subtitle — see
  /// `AppDatabase.watchNetWorth`). On by default; a user turns a specific
  /// savings goal or account off if they don't want it inflating the figure
  /// they treat as their real spendable net worth.
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();

  /// Null = this account is in the parent currency (`Settings.currencyCode`)
  /// — true for every account that existed before this feature, and for
  /// every account a user never explicitly changes. Locked once the account
  /// has a transaction (enforced in `AppDatabase.setAccountCurrency`, not
  /// here — Drift columns can't express that rule). A debit-card/UPI
  /// instrument (non-null `linkedAccountId`) never gets its own value here —
  /// it always mirrors its linked account's currency.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3).nullable()();
}

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get kind => textEnum<CategoryKind>()();
  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().withLength(min: 1, max: 40)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// A top-level category has a **null** parent. A subcategory points at its
  /// parent, which is always itself top-level — the tree is exactly two deep.
  /// A child always shares its parent's [kind].
  ///
  /// No schema-level foreign key on purpose: categories are archived, never
  /// hard-deleted, so a parent can't vanish under a child. The parent's
  /// existence, kind and single-level depth are all enforced in the DB layer
  /// ([AppDatabase.addCategory] / [AppDatabase.updateCategory]); a stray id
  /// from an old backup is treated as top-level rather than wedging a query.
  IntColumn get parentId => integer().nullable()();
}

/// A saved snapshot of a category/sub-category structure (GitHub #101) — its
/// rows live in [CategoryTemplateItems]. Independent of [Categories]: saving
/// or applying a template never touches a transaction, only which
/// `Categories` rows are archived vs. active. See
/// `docs/superpowers/specs/2026-09-06-category-templates-design.md`.
@DataClassName('CategoryTemplateRow')
class CategoryTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One category in a saved template. Mirrors [Categories]' own shape (name,
/// kind, colour, icon, two-level parent nesting) but [parentItemId] resolves
/// against *other rows of the same template*, never a live [Categories.id] —
/// a template must be applicable on a device that has never seen these
/// categories before. [AppDatabase.applyCategoryTemplate] matches these
/// against live categories by name, not id.
@DataClassName('CategoryTemplateItemRow')
class CategoryTemplateItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().references(CategoryTemplates, #id)();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get kind => textEnum<CategoryKind>()();
  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().withLength(min: 1, max: 40)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get parentItemId => integer().nullable()();
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TxType>()();

  /// Always **positive**. Direction is carried by [type], never by the sign.
  IntColumn get amount => integer().map(const MoneyConverter())();

  /// income → destination. expense → source. transfer → source.
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// transfer only → destination.
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();

  /// income/expense only. Null for transfers and person movements, by definition.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// personOut / personIn only — who the money went to or came from.
  IntColumn get personId => integer().nullable().references(Persons, #id)();

  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  /// Expense only — who got paid. Free text (not a foreign key) so it never
  /// needs a management screen of its own; the Payees hub derives its list by
  /// grouping this column instead of owning a separate table.
  TextColumn get payee => text().withLength(min: 1, max: 80).nullable()();

  /// Set when [AppDatabase.runDueRecurringRules] auto-posted this row, so the
  /// Auto hub and the Transactions list can trace it back to its rule.
  IntColumn get recurringRuleId =>
      integer().nullable().references(RecurringRules, #id)();

  /// Absolute path to a receipt photo copied into the app's own documents
  /// directory (see `receipt_storage.dart`) — never a path the app doesn't
  /// own, so nothing depends on a picked file surviving where it was picked
  /// from. Null means no receipt attached.
  TextColumn get imagePath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Set when [AppDatabase.runDueRecurringRules] posts this from a rule whose
  /// [RecurringRules.isEstimate] is true — the amount is a placeholder, not
  /// what actually happened (e.g. a salary that varies month to month).
  /// Cleared the moment the user edits and saves the transaction, by which
  /// point they've either confirmed or corrected the real figure.
  BoolColumn get needsAmountReview =>
      boolean().withDefault(const Constant(false))();

  /// Ties together the legs of one hybrid/split payment — one purchase paid
  /// from several accounts at once (see GitHub #43). Every leg in a group
  /// points at the *first* leg inserted, including that leg itself, so
  /// "every row in this group" is just `WHERE paymentGroupId = anchorId`
  /// with no separate id space to manage. Null means an ordinary,
  /// ungrouped transaction — the overwhelming majority.
  ///
  /// Deliberately not [TransactionSplits]: that ties one expense to several
  /// *categories* against a single account; this ties several *accounts*
  /// against a single category. The two are orthogonal and — for now —
  /// mutually exclusive in the UI, to avoid the 2-D matrix of splitting
  /// both at once.
  IntColumn get paymentGroupId =>
      integer().nullable().references(Transactions, #id)();

  /// What this cost in another currency, manually entered — e.g. "$9.99" for
  /// a subscription actually charged as [amount] home-currency rupees
  /// (GitHub #85). [amount] stays authoritative for every balance/net-worth/
  /// envelope computation; this is a purely informational annotation. Always
  /// null exactly when [foreignAmount] is null — never one without the
  /// other, same pairing as [RecurringRules.promoAmount]/
  /// [RecurringRules.promoOccurrencesLeft]. The implied conversion rate is
  /// `amount / foreignAmount`, recomputed for display rather than stored.
  TextColumn get foreignCurrencyCode => text().nullable()();
  IntColumn get foreignAmount =>
      integer().nullable().map(const MoneyConverter())();

  /// This transaction's own ledger currency, snapshotted from its account's
  /// [Accounts.currencyCode] at post time. Null = parent currency, which
  /// matches [amount]'s existing meaning exactly (no conversion needed).
  /// Distinct from the #85 [foreignCurrencyCode]/[foreignAmount] pair above,
  /// which is a manual informational annotation on a parent-currency
  /// transaction — this pair instead describes the transaction's *real*
  /// native currency, inherited from its account.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3).nullable()();

  /// Snapshot of `CurrencyRates.rateToBaseMicros` as of [date], for
  /// [currencyCode]. Null iff [currencyCode] is null.
  IntColumn get fxRateToBaseMicros => integer().nullable()();

  /// Transfer only, and only when the source and destination accounts don't
  /// share a currency: the amount credited to [toAccountId], in *its own*
  /// currency. Null for a same-currency transfer, where crediting [amount]
  /// unchanged is already correct — see `AppDatabase._applyTxEffect`.
  IntColumn get toAmount => integer().map(const MoneyConverter()).nullable()();

  /// Transfer only, mirrors [currencyCode]/[fxRateToBaseMicros] for the
  /// destination leg — the two accounts can each be a different currency
  /// from the parent (and from each other), so the destination needs its
  /// own independent snapshot.
  TextColumn get toCurrencyCode =>
      text().withLength(min: 3, max: 3).nullable()();
  IntColumn get toFxRateToBaseMicros => integer().nullable()();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer().map(const MoneyConverter())();
  TextColumn get period => textEnum<BudgetPeriod>()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get alertThresholdPct =>
      integer().withDefault(const Constant(80))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Free-form context for this budget — why it's set the way it is, what
  /// it's meant to cover, a reminder for next month. Entirely optional.
  TextColumn get note => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId},
  ];
}

/// One movement of money into or out of a category's envelope, for an
/// [Accounts.envelopeMode] account — the ledger behind
/// `AppDatabase.categoryBalance` / `readyToAssign`. Never touched for an
/// account with envelope mode off.
@DataClassName('AllocationRow')
class Allocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// Positive: money assigned from Ready to Assign INTO this category.
  /// Negative: money unassigned OUT of this category, back to Ready to
  /// Assign. Moving money between two categories is two rows — one negative
  /// on the source, one positive on the destination — never a single row
  /// naming both, so a category's balance is always just the sum of its own
  /// rows.
  IntColumn get amount => integer().map(const MoneyConverter())();

  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PersonRow')
class Persons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get contact => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Their UPI VPA (e.g. "rahul@okhdfcbank"). Powers the "Pay" button on
  /// their detail screen — used as `pa` on a `upi://pay` deep link when the
  /// app's user owes them (see `UpiLauncher`).
  TextColumn get upiId => text().nullable()();

  /// Their phone number. Not wired to any deep link yet (UPI links need a
  /// VPA, not a phone number) — stored for display/contact purposes.
  TextColumn get phone => text().nullable()();

  /// Their PayPal.me id (e.g. "rahul" for paypal.me/rahul). Powers the "Pay"
  /// button on their detail screen — used to build a `paypal.me` link when
  /// the app's user owes them (see `PaypalLauncher`).
  TextColumn get paypal => text().nullable()();

  /// Their Venmo username. Powers the "Pay" button — used to build a
  /// `venmo.com` deep link (see `VenmoLauncher`). US-only in practice.
  TextColumn get venmo => text().nullable()();

  /// Their Cash App cashtag (e.g. "$rahul"). Powers the "Pay" button — used
  /// to build a `cash.app` link (see `CashAppLauncher`). US-only in practice.
  TextColumn get cashapp => text().nullable()();

  /// Their Revolut.me username. Powers the "Pay" button — used to build a
  /// `revolut.me` link (see `RevolutLauncher`). Mainly useful in Europe.
  TextColumn get revolut => text().nullable()();
}

/// Signed ledger per person. Balance = Σ(theyOwe) − Σ(iOwe).
///
/// Lending/borrowing is **not** income or expense. When [accountId] is set the
/// money really moved: a linked [transactionId] (type `personOut`/`personIn`)
/// carries that movement, so the balance change is visible in the ledger while
/// staying out of income/expense reporting.
///
/// The transaction is the **single source of truth for money**. This row is the
/// source of truth for *who owes whom*.
@DataClassName('PersonEntryRow')
class PersonEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(Persons, #id)();
  TextColumn get direction => textEnum<PersonDirection>()();
  IntColumn get amount => integer().map(const MoneyConverter())();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  /// Optional: the account real money moved through.
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();

  /// Set when [accountId] is set — the ledger row that moved the money.
  IntColumn get transactionId =>
      integer().nullable().references(Transactions, #id)();

  /// Set only on a **repayment** — an [PersonDirection.iOwe] entry the user
  /// chose to count as income (see [Settings.countRepaymentsAsIncome]).
  /// When set, [transactionId] points at a real [TxType.income] row instead
  /// of the usual [TxType.personIn], so it counts in every income total the
  /// ordinary way. Null for every other entry — lending and borrowing are
  /// never income or expense.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GroupRow')
class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Junction: who belongs to a group. "Me" (the app's own user) is implicit
/// and never a row here — only named [Persons] can be members. Ordered by
/// [id] (insertion order), which is also the deterministic order a group
/// expense's rounding remainder gets distributed in (see
/// `computeGroupShares`) — so which member gets an extra paisa is stable
/// and explainable, not arbitrary.
@DataClassName('GroupMemberRow')
class GroupMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  IntColumn get personId => integer().references(Persons, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {groupId, personId},
  ];
}

enum GroupSplitMethod { equal, percentage, manual }

/// One shared-expense event. This row and [GroupExpenseShares] record *how
/// the split was computed* — they are never a second source of truth for
/// money. Every dollar this feature moves is a real [Transactions] or
/// [PersonEntries] row, created through the existing `addTransaction`/
/// `addPersonEntry` exactly the way any other entry is.
///
/// This app's ledger can only represent a debt between "me" and one named
/// Person — never between two other contacts. So: when [payerId] is null
/// (I paid), my own share becomes a real expense, and everyone else's
/// share becomes a normal "they owe me" entry. When [payerId] is set
/// (someone else paid), only *my* share (if I have one) is trackable, as
/// a normal "I owe them" entry — any other participant's share is
/// computed for display only and deliberately never persisted (see
/// `GroupExpenseShares`).
@DataClassName('GroupExpenseRow')
class GroupExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  IntColumn get amount => integer().map(const MoneyConverter())();
  TextColumn get splitMethod => textEnum<GroupSplitMethod>()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  /// Null = "me" paid. Non-null = that Person paid.
  IntColumn get payerId => integer().nullable().references(Persons, #id)();

  /// Only set when [payerId] is null (I paid) and I have a share of this
  /// expense: the account and category my own share's expense transaction
  /// posted under.
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One participant's computed share of a [GroupExpenses] row. Every
/// participant gets exactly one row here, whether or not their share ended
/// up trackable — a row with both [personEntryId] and [transactionId] null
/// is a real, computed amount that was deliberately never turned into a
/// debt (the third-party case this schema can't represent — see the class
/// doc on [GroupExpenses]).
@DataClassName('GroupExpenseShareRow')
class GroupExpenseShares extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupExpenseId => integer().references(GroupExpenses, #id)();

  /// Null = my own share.
  IntColumn get personId => integer().nullable().references(Persons, #id)();

  IntColumn get amount => integer().map(const MoneyConverter())();

  /// Informational only, e.g. `3333` = 33.33% — kept for re-displaying a
  /// percentage split; [amount] is always the money source of truth.
  IntColumn get percentBasisPoints => integer().nullable()();

  /// Set when this share became a [PersonEntries] row (every "they owe
  /// me"/"I owe them" case). Exactly one of this and [transactionId] is
  /// set for a *tracked* share; both null means untracked — either a
  /// third-party amount, or the payer's own (already-theirs) share.
  ///
  /// `onDelete: setNull` deliberately, not the usual "refuse to delete
  /// while referenced" house style ([deletePerson]/[deleteGroup]): the
  /// user can still delete this entry directly from the person's own page
  /// at any time. This share row survives with the link cleared, reading
  /// exactly like any other untracked share — a graceful downgrade, not a
  /// dangling reference `deleteGroupExpense` has to work around blind.
  IntColumn get personEntryId => integer().nullable().references(
    PersonEntries,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Set (with [personEntryId] null) only for my own share when I'm the
  /// payer — a real [TxType.expense] transaction, not a debt. Same
  /// `onDelete: setNull` reasoning as [personEntryId].
  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

/// Cash Reminders. A reminder **posts nothing on its own** — the user taps
/// "Mark as paid" and confirms. That is what makes double-counting impossible.
@DataClassName('ReminderRow')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  IntColumn get amount => integer().map(const MoneyConverter()).nullable()();
  TextColumn get direction => textEnum<ReminderDirection>()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get personId => integer().nullable().references(Persons, #id)();
  TextColumn get repeat =>
      textEnum<ReminderRepeat>().withDefault(const Constant('none'))();
  IntColumn get notifyDaysBefore => integer().withDefault(const Constant(0))();
  TextColumn get status =>
      textEnum<ReminderStatus>().withDefault(const Constant('open'))();

  /// Set once "Mark as paid" posts the real transaction.
  IntColumn get transactionId =>
      integer().nullable().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A fixed income or expense that posts itself, on a schedule, with no
/// confirmation step — unlike a [Reminders] row, which never posts on its own.
/// [AppDatabase.runDueRecurringRules] is the only thing that ever writes a
/// [Transactions] row from this table.
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Reuses [CategoryKind] rather than a bespoke enum — a rule is exactly as
  /// income-or-expense as the category it posts under. For a G&L rule (see
  /// [toAccountId]) this is always [CategoryKind.expense] — money leaves
  /// [accountId] the same direction as an expense — but it's otherwise
  /// unread: every code path branches on [toAccountId] first.
  TextColumn get kind => textEnum<CategoryKind>()();

  IntColumn get amount => integer().map(const MoneyConverter())();
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// Null for a G&L rule (see [toAccountId]) — a transfer into a goal or
  /// loan is only ever optionally tagged, exactly like
  /// [GoalDetails.categoryId]/[LoanDetails.categoryId]. Required for an
  /// expense/income rule.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// Non-null makes this a "G&L" rule: it posts a [TxType.transfer] from
  /// [accountId] to this goal or loan account instead of an
  /// income/expense transaction. Null (the common case) means the rule
  /// posts an ordinary expense/income per [kind].
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();

  /// Same free-text field as [Transactions.payee] — who the rule pays (an
  /// expense) or who it's paid by (income, e.g. an employer for a salary
  /// rule). See GitHub #62.
  TextColumn get payee => text().withLength(min: 1, max: 80).nullable()();

  /// Free-form context for the rule itself — why it exists, what it covers.
  /// Purely informational; never copied onto the transactions it posts (see
  /// GitHub #84).
  TextColumn get note => text().nullable()();

  TextColumn get frequency => textEnum<RecurringFrequency>()();

  /// Monthly only. Captured once from whichever "starts on" date is chosen —
  /// not re-derived from [nextDueDate] each time, so a month too short for it
  /// (see [nextDueDate]) still remembers the day to snap back to.
  IntColumn get dayOfMonth => integer().nullable()();

  /// The next occurrence still to be posted. A catch-up run advances this one
  /// occurrence at a time until it lands in the future, backfilling every
  /// missed date on the way — it never sits stale behind the present.
  DateTimeColumn get nextDueDate => dateTime()();

  IntColumn get notifyDaysBefore => integer().withDefault(const Constant(3))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// True for a rule whose amount isn't really fixed — a salary that depends
  /// on hours worked, production, etc. [amount] still seeds every posted
  /// occurrence (so there's always a number in the ledger the moment it's
  /// due), but that transaction comes out flagged via
  /// [Transactions.needsAmountReview] so the user is nudged to correct it to
  /// what actually landed.
  BoolColumn get isEstimate => boolean().withDefault(const Constant(false))();

  /// The discounted per-occurrence price of a running promotion (see GitHub
  /// #82) — e.g. "€2.49 for the next 3 months" instead of the usual
  /// [amount]. Null whenever no promotion is active. Always null exactly
  /// when [promoOccurrencesLeft] is null — never one without the other.
  IntColumn get promoAmount =>
      integer().nullable().map(const MoneyConverter())();

  /// How many more occurrences still post at [promoAmount] before
  /// [AppDatabase.runDueRecurringRules] automatically clears both promo
  /// fields and goes back to posting [amount] — no user action needed once
  /// the promotion is set up.
  IntColumn get promoOccurrencesLeft => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Same annotation as [Transactions.foreignCurrencyCode]/
  /// [Transactions.foreignAmount] (GitHub #85), carried on the rule so every
  /// occurrence it posts keeps showing its original foreign-currency price
  /// (e.g. a $9.99 subscription). Copied onto each posted transaction by
  /// [AppDatabase.runDueRecurringRules] — except while a promo price is
  /// active, since there is no tracked foreign equivalent for [promoAmount].
  /// Always null exactly when [foreignAmount] is null.
  TextColumn get foreignCurrencyCode => text().nullable()();
  IntColumn get foreignAmount =>
      integer().nullable().map(const MoneyConverter())();
}

/// Single-row app settings.
@DataClassName('SettingRow')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  IntColumn get budgetStartDay => integer().withDefault(const Constant(1))();
  BoolColumn get onboarded => boolean().withDefault(const Constant(false))();

  /// Auto-fill + post transactions from rules already learned. The card still
  /// shows, so the user always sees what was filled in for them.
  BoolColumn get autoApprove => boolean().withDefault(const Constant(false))();

  BoolColumn get messageCaptureEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Watermark for the "read SMS since last open" scan.
  DateTimeColumn get lastMessageScanAt => dateTime().nullable()();

  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// A `ThemePreset.name`. Stored as text rather than an enum index, so
  /// reordering the enum can never silently repaint someone's app.
  TextColumn get themeName => text()
      .withLength(min: 1, max: 30)
      .withDefault(const Constant('system'))();

  /// When false, amounts render as bare numbers — the escape hatch for a
  /// currency whose symbol we don't carry. [currencyCode] still governs grouping
  /// and decimals.
  BoolColumn get showCurrencySymbol =>
      boolean().withDefault(const Constant(true))();

  /// When true, [PersonDetailScreen] offers "Mark as repaid" — a repayment
  /// entry that posts as real income (with a chosen category) instead of the
  /// usual [TxType.personIn], so it counts toward income totals and reports.
  /// Off by default: lending/borrowing stays out of income/expense unless
  /// asked for.
  BoolColumn get countRepaymentsAsIncome =>
      boolean().withDefault(const Constant(false))();

  /// The app user's own UPI VPA. Required to build a `upi://collect` link
  /// (the "Request" button on a person who owes the user) — `pa` on a
  /// collect intent must be the *payee*, i.e. the app's own user, not the
  /// person being requested from. Null until set in Settings.
  TextColumn get myUpiId => text().nullable()();

  /// The app user's own display name, sent as `pn` on a collect link.
  TextColumn get myUpiName => text().nullable()();

  /// The app user's own PayPal.me id. Required to build the "Request" link
  /// on a person who owes the user — same identity-not-the-person's caveat
  /// as [myUpiId]. Null until set in Settings.
  TextColumn get myPaypal => text().nullable()();

  /// The app user's own Venmo username, for the "Request" link.
  TextColumn get myVenmo => text().nullable()();

  /// The app user's own Cash App cashtag, for the "Request" link.
  TextColumn get myCashapp => text().nullable()();

  /// The app user's own Revolut.me username, for the "Request" link.
  TextColumn get myRevolut => text().nullable()();

  /// Whether the UPI button/fields are offered at all. Defaults true so
  /// existing users see no change; the "Payment support" section in
  /// Settings lets someone in a country UPI doesn't reach turn it off
  /// entirely, rather than leaving a permanently-disabled button around.
  BoolColumn get upiEnabled => boolean().withDefault(const Constant(true))();

  /// Same as [upiEnabled], for PayPal.
  BoolColumn get paypalEnabled => boolean().withDefault(const Constant(true))();

  /// Same as [upiEnabled], for Venmo.
  BoolColumn get venmoEnabled => boolean().withDefault(const Constant(true))();

  /// Same as [upiEnabled], for Cash App.
  BoolColumn get cashappEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Same as [upiEnabled], for Revolut.
  BoolColumn get revolutEnabled =>
      boolean().withDefault(const Constant(true))();

  /// A salted SHA-256 hash — never the passcode itself. Null means no
  /// passcode is set, the default, and the app never locks.
  TextColumn get passcodeHash => text().nullable()();
  TextColumn get passcodeSalt => text().nullable()();

  /// How many digits [passcodeHash] was set with — 4, 5 or 6 (see GitHub
  /// #18). The hash itself doesn't care about length, only the entry/lock
  /// screens' keypads do. Null means 4: every passcode set before this
  /// column existed was 4 digits, since that was the only option.
  IntColumn get passcodeLength => integer().nullable()();

  /// Only ever offered as a shortcut once [passcodeHash] is set — the PIN
  /// stays the fallback whenever biometrics fail or aren't enrolled.
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Which numpad style the lock screen draws — see [LockScreenStyle].
  /// Defaults to `classic` so existing users see no change.
  TextColumn get lockScreenStyle =>
      textEnum<LockScreenStyle>().withDefault(const Constant('classic'))();

  /// How the More hub lays out its items — see [MoreScreenViewMode].
  /// Defaults to `list` so existing users see no change.
  TextColumn get moreScreenViewMode =>
      textEnum<MoreScreenViewMode>().withDefault(const Constant('list'))();

  /// Legacy — see [BudgetingMode]. Superseded by [rtaEnabled]; kept only for
  /// the `from < 62` migration's one-time backfill read. Nothing writes to
  /// this column anymore.
  TextColumn get budgetingMode =>
      textEnum<BudgetingMode>().withDefault(const Constant('budgets'))();

  /// Whether Ready to Assign — the shared envelope pool — is turned on
  /// globally (GitHub #100 v2). Off by default. Budget (the per-category
  /// spending ceiling) is always on regardless of this flag; this only
  /// decides whether accounts also participate in the shared RTA pool via
  /// [Accounts.envelopeMode]. Replaces [BudgetingMode] as a mutually
  /// exclusive Budgets-vs-Envelope choice — enabling this auto-enrolls
  /// every account into the pool (see `AppDatabase.setRtaEnabled`), and it
  /// turns itself back off automatically the moment the pool would
  /// otherwise go empty (see `AppDatabase._maybeAutoDisableRta`).
  BoolColumn get rtaEnabled => boolean().withDefault(const Constant(false))();

  /// Minutes the app may sit backgrounded before the next resume re-locks it
  /// — `0` means immediately (see GitHub #60). Checked against how long the
  /// app was actually paused, not a running timer, so it costs nothing while
  /// backgrounded.
  IntColumn get pinTimeoutMinutes => integer().withDefault(const Constant(0))();

  /// A salted SHA-256 hash of the master recovery phrase (GitHub #74) — same
  /// scheme as [passcodeHash], never the words themselves. Null means the
  /// feature is off. There is no "change" flow, only set-when-null and
  /// clear — like [passcodeHash] it can't be recovered if forgotten, so
  /// there is nothing a "change" step could safely verify against without
  /// prompting for the old phrase first, which is exactly what clearing +
  /// setting again already does.
  TextColumn get masterPhraseHash => text().nullable()();
  TextColumn get masterPhraseSalt => text().nullable()();

  /// How many consecutive wrong PINs (with [failedPasscodeAttempts]) force
  /// the lock screen into master-phrase-only mode. Meaningless without
  /// [masterPhraseHash] set, same guard pattern as [pinTimeoutMinutes].
  IntColumn get masterPhraseAttemptThreshold =>
      integer().withDefault(const Constant(5))();

  /// Which credential is the active front door — see [UnlockMethod]. Default
  /// `pin` so every existing install keeps today's exact behavior. Switching
  /// this never clears any other method's credential; a phrase or a PIN can
  /// stay configured and unused, or serve as [masterPhraseAttemptThreshold]'s
  /// fallback, while a different method is active.
  TextColumn get unlockMethod =>
      textEnum<UnlockMethod>().withDefault(const Constant('pin'))();

  /// A base32 TOTP secret (GitHub #104) — **not** hashed, unlike
  /// [passcodeHash]/[masterPhraseHash]. Verifying a 6-digit code means
  /// recomputing it from the secret and comparing, so the secret must stay
  /// recoverable. This adds no new trust boundary: the whole ledger already
  /// lives in this same plaintext local database. Null means the feature is
  /// off, same convention as the other two credential columns.
  TextColumn get totpSecret => text().nullable()();

  /// Consecutive wrong-PIN count on the lock screen — persisted, not reset
  /// by an app restart or by time passing (GitHub #74 asks for "no time
  /// decay"). Reset to 0 by a correct PIN or a correct master phrase.
  IntColumn get failedPasscodeAttempts =>
      integer().withDefault(const Constant(0))();

  /// A daily nudge — "log today's spending" — distinct from [Reminders],
  /// which are always for one specific planned payment.
  BoolColumn get expenseReminderEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get expenseReminderHour =>
      integer().withDefault(const Constant(20))();
  IntColumn get expenseReminderMinute =>
      integer().withDefault(const Constant(0))();

  /// A standing, silent notification with "Add expense" / "Add income"
  /// buttons — each opens an inline reply asking for an amount and posts a
  /// transaction straight from the notification shade, no need to open the
  /// app at all. Opt-in and off by default (see GitHub #38). Deliberately
  /// uncategorised (there is no UI to pick one from a reply) and posted to
  /// [quickAddAccountId] — categorise it later from the Transactions list,
  /// same as any other transaction.
  BoolColumn get notificationQuickAddEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Which account a quick-add notification reply posts to. Null falls back
  /// to the first balance-holding account (by sort order) — see
  /// `AppDatabase.resolveQuickAddAccountId`.
  IntColumn get quickAddAccountId =>
      integer().nullable().references(Accounts, #id)();

  /// Whether XPENC creates a backup on its own schedule, with no "Back up
  /// now" tap needed. Off by default.
  BoolColumn get autoBackupEnabled =>
      boolean().withDefault(const Constant(false))();

  /// How often, when [autoBackupEnabled]. `custom` uses
  /// [autoBackupCustomDays] + [autoBackupCustomHours] instead of a fixed
  /// cadence.
  TextColumn get autoBackupFrequency =>
      textEnum<AutoBackupFrequency>().withDefault(const Constant('daily'))();

  IntColumn get autoBackupCustomDays =>
      integer().withDefault(const Constant(0))();
  IntColumn get autoBackupCustomHours =>
      integer().withDefault(const Constant(0))();

  /// When the last *automatic* backup ran — the due-date anchor. A manual
  /// "Back up now" never touches this, so it can't push an automatic backup
  /// later than the schedule promises.
  DateTimeColumn get lastAutoBackupAt => dateTime().nullable()();

  /// How many days a backup is kept before automatic cleanup removes it.
  /// `0` means "keep forever". Must be at least as long as the auto-backup
  /// interval (see `AppDatabase.setAutoBackupSettings`) — otherwise cleanup
  /// could delete a backup before the next one exists to replace it.
  IntColumn get backupRetentionDays =>
      integer().withDefault(const Constant(180))();

  /// Blocks screenshots and hides XPENC from the recent-apps thumbnail —
  /// applied natively as `FLAG_SECURE` on the Android window (see
  /// `ScreenSecurity`). Off by default: it's a privacy trade-off (no
  /// screenshotting a statement to share it) the user opts into.
  BoolColumn get preventScreenshots =>
      boolean().withDefault(const Constant(false))();

  /// A small on-screen reminder whenever [preventScreenshots] is off — easy
  /// to forget it's still off after taking a screenshot on purpose (GitHub
  /// #90). Off by default and opt-in, separately from [preventScreenshots]
  /// itself: someone who deliberately leaves screenshot-blocking off is
  /// making that choice on purpose and shouldn't be nagged about it unless
  /// they ask to be.
  BoolColumn get screenshotReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Masks every amount rendered anywhere in the app (see
  /// `AmountVisibilityScope` in `money_text.dart`) — flipped from the eye
  /// icon in the top bar (`AppShell`). Persisted, not session-only: hiding
  /// amounts is usually done right before handing the phone to someone, and
  /// should still be hidden the next time the app opens, not reset.
  BoolColumn get hideAmounts => boolean().withDefault(const Constant(false))();

  /// Which of the 7 catalog destinations occupy the two configurable
  /// bottom-nav slots flanking the ➕ button — left, then right. Dashboard
  /// and More are pinned and never appear here (see `AppShell`'s
  /// `BottomNavCatalog`). GitHub #70.
  TextColumn get bottomNavSlots =>
      text().withDefault(const Constant('transactions,persons'))();

  /// Whether each bottom-nav item shows its small text label under the icon.
  /// On by default; off collapses the bar to icon-only.
  BoolColumn get showBottomNavLabels =>
      boolean().withDefault(const Constant(true))();

  /// Off by default — press-and-hold the ➕ button is a new, undiscoverable
  /// gesture on a control every existing user already knows; asking them to
  /// opt in avoids surprising anyone who just wants to add a transaction.
  /// When on, holding ➕ floats 3 quick-access options (see
  /// [holdMenuSlots]) the user drags a finger toward to jump to that
  /// destination, without lifting.
  BoolColumn get holdMenuEnabled =>
      boolean().withDefault(const Constant(false))();

  /// The 3 destinations the hold-➕ menu offers, comma-joined, same catalog
  /// and id set as [bottomNavSlots] (`AppShell._catalog` /
  /// `AppDatabase.bottomNavCatalogIds`). Deliberately allowed to overlap
  /// with `bottomNavSlots` — quick access via a hold gesture and a pinned
  /// tab aren't mutually exclusive.
  TextColumn get holdMenuSlots =>
      text().withDefault(const Constant('calendar,budgets,stats'))();

  /// Whether the calendar's selected-day section shows an inflow/outflow
  /// total strip. On by default; the on/off toggle lives in Settings
  /// (GitHub #75).
  BoolColumn get showCalendarDayTotals =>
      boolean().withDefault(const Constant(true))();

  /// Global text-size multiplier, as a percentage — 100 is the app's normal
  /// size. Applied as a `TextScaler` over the whole app (see `XpencApp`),
  /// not baked into the theme, so it also scales third-party widget text.
  IntColumn get fontScalePercent =>
      integer().withDefault(const Constant(100))();

  /// How much bolder (positive) or lighter (negative) every text style
  /// reads versus its theme's own weight — one step is one `FontWeight`
  /// rung (100 units). See `AppTheme._applyWeightDelta`.
  IntColumn get fontWeightDelta => integer().withDefault(const Constant(0))();

  /// An `AppFontFamily.name`, or null to keep each theme's own font choice
  /// (see `ThemeShape.displayFontFamily`/`bodyFontFamily`). Unknown values
  /// degrade to null on read, same convention as [themeName].
  TextColumn get fontFamily => text().nullable()();

  /// Extra logical pixels of bottom clearance added app-wide, on top of
  /// whatever the OS reports as the system nav bar's safe-area inset — a
  /// manual escape hatch for OEM devices that misreport (or don't report at
  /// all) how much of the screen their on-screen nav bar covers, which left
  /// the bottom nav bar and the PIN lock screen's keypad overlapped by it
  /// (GitHub #78). Applied once, in `XpencApp`'s `builder`, to the `padding`
  /// every `SafeArea` in the app reads from — see `AppShell` and
  /// `LockScreen`, neither of which needed any change themselves.
  IntColumn get extraBottomInset => integer().withDefault(const Constant(0))();

  /// Icon keys (see `AppIcons`) picked from the icon sheet, most-recent-first,
  /// comma-joined — same convention as [bottomNavSlots]. Powers the
  /// "Frequently used" row so the icon someone reaches for constantly (their
  /// coffee cup, their gym) surfaces without scrolling or typing a search.
  TextColumn get frequentIconKeys => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Message auto-capture (§8) ──────────────────────────────────────────────

/// A parsed bank message waiting for the user. Nothing here has touched the
/// ledger yet unless [status] is `autoFilled` or `approved`.
@DataClassName('PendingTxnRow')
class PendingTxns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => textEnum<MessageSourceKind>()();
  TextColumn get rawBody => text()();
  TextColumn get sender => text()();
  DateTimeColumn get receivedAt => dateTime()();

  IntColumn get parsedAmount =>
      integer().map(const MoneyConverter()).nullable()();
  TextColumn get parsedDirection => textEnum<TxDirection>().nullable()();

  /// Last 4 digits lifted from `A/c XX1234` / `Card ending 5678`.
  TextColumn get parsedAccountHint => text().nullable()();
  TextColumn get parsedMerchant => text().nullable()();
  TextColumn get parsedRef => text().nullable()();
  IntColumn get parsedBalance =>
      integer().map(const MoneyConverter()).nullable()();

  /// 0–100. Low confidence never auto-posts.
  IntColumn get confidence => integer().withDefault(const Constant(0))();

  TextColumn get status =>
      textEnum<PendingStatus>().withDefault(const Constant('pending'))();

  IntColumn get matchedAccountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get appliedRuleId => integer().nullable()();
  IntColumn get createdTransactionId =>
      integer().nullable().references(Transactions, #id)();

  /// Stable identity for dedupe: sender + body + received-minute.
  TextColumn get dedupeKey => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Set only for [MessageSourceKind.screenshot] cards: the shared image,
  /// already copied into the app's own `documents/receipts/` directory (see
  /// `ReceiptStorage.storeExternalFile`) — the same directory a manually
  /// attached receipt lives in, so an approved card needs no second copy:
  /// this path is used directly as the new transaction's `imagePath`.
  TextColumn get sourceImagePath => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {dedupeKey},
  ];
}

/// A user-submitted example of what XPENC's on-device OCR read from a
/// payment-app screenshot, and whether the parser's extraction was right —
/// see Settings > Message Capture > OCR corrections and
/// docs/superpowers/specs/2026-08-14-ocr-corrections-design.md. Never holds
/// the source image, only text. [sentAt] is set once the user has fired a
/// send intent (mailto/share sheet) for this row — the app itself never
/// transmits it.
@DataClassName('OcrCorrectionRow')
class OcrCorrections extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get appLabel => text()();
  TextColumn get country => text().nullable()();
  TextColumn get rawOcrText => text()();
  BoolColumn get wasCorrect => boolean()();

  /// What `ScreenshotParser` actually produced — kept as display strings,
  /// not typed `Money`/`TxDirection`, since these are export-only and never
  /// feed back into the ledger.
  TextColumn get extractedAmount => text().nullable()();
  TextColumn get extractedDirection => text().nullable()();
  TextColumn get extractedPayee => text().nullable()();
  TextColumn get extractedReference => text().nullable()();

  /// Only set when [wasCorrect] is false.
  TextColumn get correctedAmount => text().nullable()();
  TextColumn get correctedDirection => text().nullable()();
  TextColumn get correctedPayee => text().nullable()();
  TextColumn get correctedReference => text().nullable()();

  DateTimeColumn get sentAt => dateTime().nullable()();
}

/// Learned "this merchant means this category" mappings. Auto-Approve only ever
/// fires from one of these — never from a fresh guess.
@DataClassName('MerchantRuleRow')
class MerchantRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get matchPattern => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  BoolColumn get autoApprove => boolean().withDefault(const Constant(true))();
  IntColumn get hitCount => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {matchPattern},
  ];
}

/// Which SMS sender IDs belong to which bank.
@DataClassName('SenderRuleRow')
class SenderRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get senderPattern => text()();
  TextColumn get bankName => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {senderPattern},
  ];
}

/// A short, user-defined label (e.g. "Work trip", "Tax deductible") that can
/// be pinned to any number of transactions, cutting across category and
/// account — unlike a category, a transaction can carry several at once.
@DataClassName('TagRow')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get colorValue => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}

/// Many-to-many join: which tags sit on which transaction.
@DataClassName('TransactionTagRow')
class TransactionTags extends Table {
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

/// Many-to-many join: which tags a recurring rule stamps onto every
/// transaction it posts (see [AppDatabase.runDueRecurringRules]) — set once
/// on the rule instead of retagging each auto-posted transaction by hand.
/// See GitHub #63.
@DataClassName('RecurringRuleTagRow')
class RecurringRuleTags extends Table {
  IntColumn get ruleId => integer().references(RecurringRules, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {ruleId, tagId};
}

/// A named bundle of [Tags] (e.g. "Work trip" = Travel + Meals + Client) —
/// picked as one unit from [TagPickerSheet] instead of hunting down each tag
/// individually every time the same combination gets used. See GitHub #92.
///
/// Purely a shortcut for *selecting* tags: applying a group to a transaction
/// still just writes ordinary [TransactionTags] rows, so nothing downstream
/// (filters, stats, exports) needs to know groups exist at all.
@DataClassName('TagGroupRow')
class TagGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}

/// Many-to-many join: which tags belong to a [TagGroups] bundle.
@DataClassName('TagGroupTagRow')
class TagGroupTags extends Table {
  IntColumn get groupId => integer().references(TagGroups, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {groupId, tagId};
}

/// One named shopping list (e.g. "Weekly groceries", "Diwali"). A user can
/// keep any number of these side by side — see [ShoppingItems].
@DataClassName('ShoppingListRow')
class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One item on a [ShoppingLists] list. Deliberately not linked to the
/// ledger: checking an item off doesn't post anything, it's just a plan for a
/// transaction someone adds separately when they actually buy it.
@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nullable only because SQLite can't add a NOT NULL column to a table
  /// that already has rows without a default — every item made before named
  /// lists existed gets backfilled onto one default list during the v17
  /// migration, and every item from then on always gets one at insert time
  /// (see AppDatabase.addShoppingItem). Never actually null in practice.
  IntColumn get listId => integer().nullable().references(ShoppingLists, #id)();

  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get estimatedAmount =>
      integer().map(const MoneyConverter()).nullable()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// The target/deadline for a [AccountType.goal] account — one row per goal
/// account, [accountId] doubling as this table's own primary key. Everything
/// else a goal needs (name, colour, icon, balance, archived) already lives on
/// its [Accounts] row, so it isn't duplicated here.
///
/// "Contributing" is an ordinary [TxType.transfer] into the goal account
/// through the normal Add Transaction flow (or the goal screen's own Add
/// funds / Withdraw shortcut) — no parallel ledger, nothing that can drift
/// from the real money.
@DataClassName('GoalDetailRow')
class GoalDetails extends Table {
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get targetAmount => integer().map(const MoneyConverter())();
  DateTimeColumn get targetDate => dateTime().nullable()();

  /// The Category a contribution is tagged with by default (GitHub #70-adjacent).
  /// Null means contributions aren't counted toward any budget.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// Free-form notes about the goal — e.g. why it exists or what it's for
  /// (GitHub #76). Purely informational; never read by any calculation.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// The extra details for a [AccountType.loan] account — principal is
/// `-Accounts.openingBalance`, outstanding is `-Accounts.currentBalance`.
@DataClassName('LoanDetailRow')
class LoanDetails extends Table {
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// The Category a payment is tagged with by default.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// Pre-fills the payment sheet amount — informational, never enforced.
  IntColumn get emiAmount => integer().map(const MoneyConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// Opt-in statement/due-date tracking for a credit card account (GitHub
/// #91) — off unless the user turns it on for that card, via
/// [CreditCardStatementSection]. Absent means "not tracked", same as
/// [LoanDetails]/[GoalDetails] being absent for an account of the wrong type.
@DataClassName('CreditCardDetailRow')
class CreditCardDetails extends Table {
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// Day of the month the statement closes (1-31). Snapped to the last real
  /// day of a shorter month, same rule a monthly [RecurringRules] rule uses.
  IntColumn get statementDay => integer()();

  /// Day of the month payment is due. Whether this falls in the same month
  /// as the close or the next one is derived from comparing the two days,
  /// not stored — see `AppDatabase.creditCardNextDueDate`.
  IntColumn get dueDay => integer()();

  /// How many days before the due date to notify — mirrors
  /// [RecurringRules.notifyDaysBefore].
  IntColumn get notifyDaysBefore => integer().withDefault(const Constant(3))();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// One category's slice of a split expense. A transaction with 2+ rows here
/// is "split" — its own [Transactions.categoryId] is null, exactly like a
/// transfer has none, because there is no single category left to name. The
/// row amounts must sum to the parent transaction's [Transactions.amount].
@DataClassName('TransactionSplitRow')
class TransactionSplits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer().map(const MoneyConverter())();
}

/// One row per (category, period, level) so an alert fires at most once.
@DataClassName('BudgetAlertRow')
class BudgetAlerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// e.g. `2026-07`.
  TextColumn get periodKey => text()();
  TextColumn get level => textEnum<AlertLevel>()();
  DateTimeColumn get firedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, periodKey, level},
  ];
}

/// One backup file XPENC knows about, living in the public
/// `Download/BACKUP XPENC` folder on the device (see `BackupService`).
///
/// Android's scoped storage has no "list every file in a folder I created"
/// call without a fresh, user-granted SAF permission — so this table *is*
/// the listing every screen reads from. `BackupService.saveBackup` keeps it
/// in sync as backups are written or deleted; `BackupService.resyncFromDevice`
/// rebuilds it from scratch by asking the user to grant folder access once
/// (e.g. after a reinstall, when this table starts out empty but the files
/// on disk still exist).
@DataClassName('BackupRecordRow')
class BackupRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();

  /// A MediaStore `content://` URI — the only reliable handle once a file is
  /// written, since scoped storage never promises a stable filesystem path.
  TextColumn get uri => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {fileName},
  ];
}

/// Many-to-many join: a manual, bidirectional link between two
/// transactions — e.g. an old charge and its refund — so each one carries a
/// button straight to the other, the way GitHub links two issues (see
/// GitHub #64). One row per *pair*, never per direction:
/// [AppDatabase.addTransactionLink] always stores the smaller id as
/// [transactionAId], so A-B and B-A can never both exist, and every read
/// queries `WHERE transactionAId = id OR transactionBId = id` to get both
/// directions back out of that single row.
@DataClassName('TransactionLinkRow')
class TransactionLinks extends Table {
  IntColumn get transactionAId => integer().references(Transactions, #id)();
  IntColumn get transactionBId => integer().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {transactionAId, transactionBId};
}
