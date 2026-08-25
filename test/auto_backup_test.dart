import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/backup_service.dart';

/// Automatic backups (schedule, due-date math, retention cleanup) and
/// "Clear all data" — none of this touches the actual MediaStore plugin
/// (that needs a real device), but every rule around *when* a backup runs
/// and *what* gets kept or wiped is pure Dart, and is covered here.
void main() {
  group('autoBackupInterval', () {
    test('daily is 1 day', () {
      expect(
        autoBackupInterval(frequency: AutoBackupFrequency.daily),
        const Duration(days: 1),
      );
    });

    test('monthly is approximated as 30 days', () {
      expect(
        autoBackupInterval(frequency: AutoBackupFrequency.monthly),
        const Duration(days: 30),
      );
    });

    test('custom combines days and hours', () {
      expect(
        autoBackupInterval(
          frequency: AutoBackupFrequency.custom,
          customDays: 2,
          customHours: 12,
        ),
        const Duration(days: 2, hours: 12),
      );
    });
  });

  group('isAutoBackupDue', () {
    SettingRow settingsWith({
      bool enabled = true,
      AutoBackupFrequency frequency = AutoBackupFrequency.daily,
      int customDays = 0,
      int customHours = 0,
      DateTime? lastAutoBackupAt,
    }) => SettingRow(
      id: 1,
      currencyCode: 'INR',
      budgetStartDay: 1,
      onboarded: true,
      autoApprove: false,
      messageCaptureEnabled: false,
      notificationsEnabled: true,
      themeName: 'system',
      showCurrencySymbol: true,
      countRepaymentsAsIncome: false,
      biometricEnabled: false,
      expenseReminderEnabled: false,
      expenseReminderHour: 20,
      expenseReminderMinute: 0,
      notificationQuickAddEnabled: false,
      autoBackupEnabled: enabled,
      autoBackupFrequency: frequency,
      autoBackupCustomDays: customDays,
      autoBackupCustomHours: customHours,
      lastAutoBackupAt: lastAutoBackupAt,
      backupRetentionDays: 180,
      preventScreenshots: false,
      hideAmounts: false,
      pinTimeoutMinutes: 0,
      bottomNavSlots: 'transactions,persons',
      showCalendarDayTotals: true,
      fontScalePercent: 100,
      fontWeightDelta: 0,
    );

    final now = DateTime(2026, 8, 5, 12);

    test('disabled is never due, even if never run', () {
      expect(isAutoBackupDue(settingsWith(enabled: false), now), isFalse);
    });

    test('never run is due immediately', () {
      expect(
        isAutoBackupDue(settingsWith(lastAutoBackupAt: null), now),
        isTrue,
      );
    });

    test('daily: not due 12 hours in, due 25 hours in', () {
      expect(
        isAutoBackupDue(
          settingsWith(
            lastAutoBackupAt: now.subtract(const Duration(hours: 12)),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        isAutoBackupDue(
          settingsWith(
            lastAutoBackupAt: now.subtract(const Duration(hours: 25)),
          ),
          now,
        ),
        isTrue,
      );
    });

    test('monthly: not due at 29 days, due at 31 days', () {
      expect(
        isAutoBackupDue(
          settingsWith(
            frequency: AutoBackupFrequency.monthly,
            lastAutoBackupAt: now.subtract(const Duration(days: 29)),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        isAutoBackupDue(
          settingsWith(
            frequency: AutoBackupFrequency.monthly,
            lastAutoBackupAt: now.subtract(const Duration(days: 31)),
          ),
          now,
        ),
        isTrue,
      );
    });

    test('custom: respects days + hours together', () {
      final justUnder = settingsWith(
        frequency: AutoBackupFrequency.custom,
        customDays: 2,
        customHours: 12,
        lastAutoBackupAt: now.subtract(const Duration(days: 2, hours: 11)),
      );
      final atOrPast = settingsWith(
        frequency: AutoBackupFrequency.custom,
        customDays: 2,
        customHours: 12,
        lastAutoBackupAt: now.subtract(const Duration(days: 2, hours: 12)),
      );
      expect(isAutoBackupDue(justUnder, now), isFalse);
      expect(isAutoBackupDue(atOrPast, now), isTrue);
    });
  });

  group('AppDatabase auto-backup settings', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('persists a valid schedule', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.monthly,
        retentionDays: 180,
      );
      final s = await db.getSettings();
      expect(s.autoBackupEnabled, isTrue);
      expect(s.autoBackupFrequency, AutoBackupFrequency.monthly);
      expect(s.backupRetentionDays, 180);
    });

    test('rejects retention shorter than the backup interval', () {
      expect(
        () => db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.monthly,
          retentionDays: 8, // shorter than the ~30-day monthly interval
        ),
        throwsArgumentError,
      );
    });

    test('"keep forever" (0) is always allowed', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.monthly,
        retentionDays: 0,
      );
      expect((await db.getSettings()).backupRetentionDays, 0);
    });

    test('rejects a zero-length custom interval', () {
      expect(
        () => db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.custom,
          customDays: 0,
          customHours: 0,
          retentionDays: 30,
        ),
        throwsArgumentError,
      );
    });

    test('accepts a custom interval right at the retention boundary', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.custom,
        customDays: 5,
        customHours: 0,
        retentionDays: 5,
      );
      expect((await db.getSettings()).backupRetentionDays, 5);
    });
  });

  group('backup records', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'upserting the same fileName updates rather than duplicates',
      () async {
        await db.upsertBackupRecord(
          fileName: '050826XPENCEBACKUP.json',
          uri: 'content://a',
          sizeBytes: 100,
          createdAt: DateTime(2026, 8, 5, 9),
        );
        await db.upsertBackupRecord(
          fileName: '050826XPENCEBACKUP.json',
          uri: 'content://a-replaced',
          sizeBytes: 250,
          createdAt: DateTime(2026, 8, 5, 18),
        );

        final all = await db.watchBackupRecords().first;
        expect(all, hasLength(1));
        expect(all.single.uri, 'content://a-replaced');
        expect(all.single.sizeBytes, 250);
      },
    );

    test('staleBackupRecords finds only what is past retention', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.daily,
        retentionDays: 8,
      );
      final now = DateTime(2026, 8, 5);
      await db.upsertBackupRecord(
        fileName: 'recent.json',
        uri: 'content://recent',
        sizeBytes: 1,
        createdAt: now.subtract(const Duration(days: 3)),
      );
      await db.upsertBackupRecord(
        fileName: 'old.json',
        uri: 'content://old',
        sizeBytes: 1,
        createdAt: now.subtract(const Duration(days: 20)),
      );

      final stale = await db.staleBackupRecords(now: now);
      expect(stale.map((r) => r.fileName), ['old.json']);
    });

    test('retention of 0 (forever) never reports anything stale', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.daily,
        retentionDays: 0,
      );
      await db.upsertBackupRecord(
        fileName: 'ancient.json',
        uri: 'content://ancient',
        sizeBytes: 1,
        createdAt: DateTime(2020),
      );
      expect(await db.staleBackupRecords(), isEmpty);
    });

    test('deleteBackupRecordByName removes just that one', () async {
      await db.upsertBackupRecord(
        fileName: 'a.json',
        uri: 'content://a',
        sizeBytes: 1,
        createdAt: DateTime(2026, 8, 1),
      );
      await db.upsertBackupRecord(
        fileName: 'b.json',
        uri: 'content://b',
        sizeBytes: 1,
        createdAt: DateTime(2026, 8, 2),
      );
      await db.deleteBackupRecordByName('a.json');

      final all = await db.watchBackupRecords().first;
      expect(all.map((r) => r.fileName), ['b.json']);
    });
  });

  group('clearAllData', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> cashId() async => (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    Future<int> catId(CategoryKind k, String name) async =>
        (await db.watchCategories(k).first)
            .firstWhere((c) => c.name == name)
            .id;

    test(
      'wipes the ledger but reseeds the same defaults a new install gets',
      () async {
        final cash = await cashId();
        await db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(5000),
          accountId: cash,
          categoryId: await catId(CategoryKind.income, 'Salary'),
          date: DateTime(2026, 7, 1),
        );
        final ram = await db.addPerson('Ram');
        await db.addPersonEntry(
          personId: ram,
          direction: PersonDirection.theyOwe,
          amount: Money.fromRupees(500),
          date: DateTime(2026, 7, 5),
          accountId: cash,
        );
        await db.upsertBudget(
          categoryId: await catId(CategoryKind.expense, 'Food'),
          amount: Money.fromRupees(6000),
        );

        final freshAccounts = await db.watchAccounts().first;
        final freshExpenseCats = await db
            .watchCategories(CategoryKind.expense)
            .first;
        final freshIncomeCats = await db
            .watchCategories(CategoryKind.income)
            .first;

        await db.clearAllData();

        expect(await db.watchTransactions().first, isEmpty);
        expect(await db.watchAllPersonBalances().first, isEmpty);
        expect(await db.watchBudgets().first, isEmpty);
        expect(await db.watchPersons().first, isEmpty);

        final accountsAfter = await db.watchAccounts().first;
        expect(accountsAfter, hasLength(1));
        expect(accountsAfter.single.name, 'Cash');
        expect(accountsAfter.single.currentBalance, const Money.zero());

        expect(
          (await db.watchCategories(CategoryKind.expense).first).length,
          freshExpenseCats.length,
        );
        expect(
          (await db.watchCategories(CategoryKind.income).first).length,
          freshIncomeCats.length,
        );
        // Sanity: this really is the same default shape a brand-new database
        // seeds, not a coincidentally-equal count.
        expect(freshAccounts, hasLength(1));
      },
    );

    test('preferences survive — this resets data, not settings', () async {
      await db.setShowCurrencySymbol(false);
      await db.clearAllData();
      expect((await db.getSettings()).showCurrencySymbol, isFalse);
    });

    test(
      'backup records are left alone — they describe files on disk, not ledger data',
      () async {
        await db.upsertBackupRecord(
          fileName: '040826XPENCEBACKUP.json',
          uri: 'content://kept',
          sizeBytes: 42,
          createdAt: DateTime(2026, 8, 4),
        );
        await db.clearAllData();
        expect(await db.watchBackupRecords().first, hasLength(1));
      },
    );
  });

  group('BackupService filename scheme', () {
    test('backupFileName is DDMMYY + XPENCEBACKUP.json', () {
      expect(
        BackupService.backupFileName(DateTime(2026, 8, 5)),
        '050826XPENCEBACKUP.json',
      );
      expect(
        BackupService.backupFileName(DateTime(2026, 12, 31)),
        '311226XPENCEBACKUP.json',
      );
    });

    test('dateFromBackupFileName reverses backupFileName', () {
      final d = DateTime(2026, 8, 5);
      expect(
        BackupService.dateFromBackupFileName(BackupService.backupFileName(d)),
        d,
      );
    });

    test('dateFromBackupFileName rejects anything else in the folder', () {
      expect(BackupService.dateFromBackupFileName('random-file.json'), isNull);
      expect(BackupService.dateFromBackupFileName('notes.txt'), isNull);
      // An invalid calendar date (32nd of the 13th) must not silently roll
      // over into some other valid date.
      expect(
        BackupService.dateFromBackupFileName('321399XPENCEBACKUP.json'),
        isNull,
      );
    });
  });
}
