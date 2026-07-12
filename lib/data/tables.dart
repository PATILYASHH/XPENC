import 'package:drift/drift.dart';

import '../core/money.dart';

// ─── Enums ──────────────────────────────────────────────────────────────────

/// Where money sits. Only Cash, Bank and *credit* Card hold a real balance.
enum AccountType { cash, bank, card }

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
  bool get isIncomeOrExpense =>
      this == TxType.income || this == TxType.expense;

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
enum MessageSourceKind { sms, notification }

/// Banking sense: `debit` = money out, `credit` = money in.
/// (Distinct from a *credit card*, which is an account.)
enum TxDirection { debit, credit }

enum PendingStatus { pending, autoFilled, approved, dismissed, duplicate }

/// Which budget alert already fired this period, so we never spam.
enum AlertLevel { threshold, overspent }

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
  IntColumn get toAccountId =>
      integer().nullable().references(Accounts, #id)();

  /// income/expense only. Null for transfers and person movements, by definition.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// personOut / personIn only — who the money went to or came from.
  IntColumn get personId => integer().nullable().references(Persons, #id)();

  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer().map(const MoneyConverter())();
  TextColumn get period => textEnum<BudgetPeriod>()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get alertThresholdPct => integer().withDefault(const Constant(80))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId},
      ];
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
  TextColumn get themeName =>
      text().withLength(min: 1, max: 30).withDefault(const Constant('system'))();

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

  @override
  List<Set<Column>> get uniqueKeys => [
        {dedupeKey},
      ];
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
