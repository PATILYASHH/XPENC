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
enum AccountType { cash, bank, card, payLater, prepaidBalance, goal }

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

// ─── Converters ─────────────────────────────────────────────────────────────

/// Money crosses the DB boundary as an integer number of paise. Never a double.
class MoneyConverter extends TypeConverter<Money, int> {
  const MoneyConverter();

  @override
  Money fromSql(int fromDb) => Money(fromDb);

  @override
  int toSql(Money value) => value.paise;
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

  /// Turns this one account into "every rupee has a job" budgeting — an
  /// expense on it must carry a category, and that category's balance is
  /// funded from this account's own Ready to Assign via [Allocations]. Off
  /// by default and per-account: every other account keeps working exactly
  /// as it does today. See `AppDatabase.categoryBalance` / `readyToAssign`.
  BoolColumn get envelopeMode => boolean().withDefault(const Constant(false))();
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
  /// income-or-expense as the category it posts under.
  TextColumn get kind => textEnum<CategoryKind>()();

  IntColumn get amount => integer().map(const MoneyConverter())();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// Same free-text field as [Transactions.payee] — who the rule pays (an
  /// expense) or who it's paid by (income, e.g. an employer for a salary
  /// rule). See GitHub #62.
  TextColumn get payee => text().withLength(min: 1, max: 80).nullable()();

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

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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

  /// Minutes the app may sit backgrounded before the next resume re-locks it
  /// — `0` means immediately (see GitHub #60). Checked against how long the
  /// app was actually paused, not a running timer, so it costs nothing while
  /// backgrounded.
  IntColumn get pinTimeoutMinutes =>
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

  /// Masks every amount rendered anywhere in the app (see
  /// `AmountVisibilityScope` in `money_text.dart`) — flipped from the eye
  /// icon in the top bar (`AppShell`). Persisted, not session-only: hiding
  /// amounts is usually done right before handing the phone to someone, and
  /// should still be hidden the next time the app opens, not reset.
  BoolColumn get hideAmounts =>
      boolean().withDefault(const Constant(false))();

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
