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
      int cooldownMinutes = 10,
      bool pending = false,
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
      autoBackupCooldownMinutes: cooldownMinutes,
      autoBackupPending: pending,
      lastAutoBackupAt: lastAutoBackupAt,
      appMode: AppMode.medium,
      backupRetentionMode: BackupRetentionMode.days,
      backupRetentionDays: 180,
      backupRetentionCount: 0,
      preventScreenshots: false,
      hideAmounts: false,
      pinTimeoutMinutes: 0,
      bottomNavSlots: 'transactions,persons',
      showBottomNavLabels: true,
      showCalendarDayTotals: true,
      fontScalePercent: 100,
      fontWeightDelta: 0,
      masterPhraseAttemptThreshold: 5,
      failedPasscodeAttempts: 0,
      extraBottomInset: 0,
      holdMenuEnabled: false,
      holdMenuSlots: 'calendar,budgets,stats',
      upiEnabled: true,
      paypalEnabled: true,
      venmoEnabled: true,
      cashappEnabled: true,
      revolutEnabled: true,
      ussdPayEnabled: false,
      lockScreenStyle: LockScreenStyle.classic,
      unlockMethod: UnlockMethod.pin,
      pinUnlockEnabled: true,
      masterPhraseUnlockEnabled: false,
      totpUnlockEnabled: false,
      screenshotReminderEnabled: false,
      moreScreenViewMode: MoreScreenViewMode.list,
      frequentIconKeys: '',
      budgetingMode: BudgetingMode.budgets,
      rtaEnabled: false,
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

    group('onChange (GitHub #132)', () {
      test(
        'no pending change is never due, no matter how much time passed',
        () {
          expect(
            isAutoBackupDue(
              settingsWith(
                frequency: AutoBackupFrequency.onChange,
                pending: false,
                lastAutoBackupAt: now.subtract(const Duration(days: 30)),
              ),
              now,
            ),
            isFalse,
          );
        },
      );

      test('a pending change with no prior backup is due immediately', () {
        expect(
          isAutoBackupDue(
            settingsWith(
              frequency: AutoBackupFrequency.onChange,
              pending: true,
              lastAutoBackupAt: null,
            ),
            now,
          ),
          isTrue,
        );
      });

      test('a pending change inside the cooldown is not yet due', () {
        expect(
          isAutoBackupDue(
            settingsWith(
              frequency: AutoBackupFrequency.onChange,
              cooldownMinutes: 10,
              pending: true,
              lastAutoBackupAt: now.subtract(const Duration(minutes: 9)),
            ),
            now,
          ),
          isFalse,
        );
      });

      test('a pending change past the cooldown is due', () {
        expect(
          isAutoBackupDue(
            settingsWith(
              frequency: AutoBackupFrequency.onChange,
              cooldownMinutes: 10,
              pending: true,
              lastAutoBackupAt: now.subtract(const Duration(minutes: 10)),
            ),
            now,
          ),
          isTrue,
        );
      });

      test('cooldown of 0 means every change is due right away', () {
        expect(
          isAutoBackupDue(
            settingsWith(
              frequency: AutoBackupFrequency.onChange,
              cooldownMinutes: 0,
              pending: true,
              lastAutoBackupAt: now,
            ),
            now,
          ),
          isTrue,
        );
      });
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

    test('GitHub #123: accepts a pure hours-only interval — 0 days is not a '
        'placeholder that has to be bumped to at least 1', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.custom,
        customDays: 0,
        customHours: 12,
        retentionDays: 8,
      );
      final s = await db.getSettings();
      expect(s.autoBackupCustomDays, 0);
      expect(s.autoBackupCustomHours, 12);
      expect(
        autoBackupInterval(
          frequency: s.autoBackupFrequency,
          customDays: s.autoBackupCustomDays,
          customHours: s.autoBackupCustomHours,
        ),
        const Duration(hours: 12),
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

    test('GitHub #131: count mode persists the count and ignores the days '
        'interval check', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.daily,
        retentionMode: BackupRetentionMode.count,
        retentionDays: 0,
        retentionCount: 3,
      );
      final s = await db.getSettings();
      expect(s.backupRetentionMode, BackupRetentionMode.count);
      expect(s.backupRetentionCount, 3);
    });

    test('count mode rejects a count below 1', () {
      expect(
        () => db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.daily,
          retentionMode: BackupRetentionMode.count,
          retentionDays: 0,
          retentionCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('onChange mode persists its cooldown', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.onChange,
        cooldownMinutes: 15,
        retentionDays: 0,
      );
      final s = await db.getSettings();
      expect(s.autoBackupFrequency, AutoBackupFrequency.onChange);
      expect(s.autoBackupCooldownMinutes, 15);
    });

    test('onChange mode rejects a negative cooldown', () {
      expect(
        () => db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.onChange,
          cooldownMinutes: -1,
          retentionDays: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('markLedgerChanged (GitHub #132)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('sets the pending flag only in onChange mode', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.daily,
        retentionDays: 180,
      );
      await db.markLedgerChanged();
      expect((await db.getSettings()).autoBackupPending, isFalse);
    });

    test('sets the pending flag when enabled and in onChange mode', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.onChange,
        cooldownMinutes: 10,
        retentionDays: 0,
      );
      await db.markLedgerChanged();
      expect((await db.getSettings()).autoBackupPending, isTrue);
    });

    test('does nothing when automatic backups are off', () async {
      await db.setAutoBackupSettings(
        enabled: false,
        frequency: AutoBackupFrequency.onChange,
        cooldownMinutes: 10,
        retentionDays: 0,
      );
      await db.markLedgerChanged();
      expect((await db.getSettings()).autoBackupPending, isFalse);
    });

    test('setLastAutoBackupAt clears a pending change', () async {
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.onChange,
        cooldownMinutes: 10,
        retentionDays: 0,
      );
      await db.markLedgerChanged();
      expect((await db.getSettings()).autoBackupPending, isTrue);

      await db.setLastAutoBackupAt(DateTime(2026, 8, 5));
      final s = await db.getSettings();
      expect(s.autoBackupPending, isFalse);
      expect(s.lastAutoBackupAt, DateTime(2026, 8, 5));
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

    test(
      'GitHub #131: count mode keeps the newest N, reports the rest stale',
      () async {
        await db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.daily,
          retentionMode: BackupRetentionMode.count,
          retentionDays: 0,
          retentionCount: 2,
        );
        final now = DateTime(2026, 8, 5);
        await db.upsertBackupRecord(
          fileName: 'newest.json',
          uri: 'content://newest',
          sizeBytes: 1,
          createdAt: now,
        );
        await db.upsertBackupRecord(
          fileName: 'middle.json',
          uri: 'content://middle',
          sizeBytes: 1,
          createdAt: now.subtract(const Duration(days: 1)),
        );
        await db.upsertBackupRecord(
          fileName: 'oldest.json',
          uri: 'content://oldest',
          sizeBytes: 1,
          createdAt: now.subtract(const Duration(days: 2)),
        );

        final stale = await db.staleBackupRecords(now: now);
        expect(stale.map((r) => r.fileName), ['oldest.json']);
      },
    );

    test(
      'count mode with fewer backups than the count reports nothing stale',
      () async {
        await db.setAutoBackupSettings(
          enabled: true,
          frequency: AutoBackupFrequency.daily,
          retentionMode: BackupRetentionMode.count,
          retentionDays: 0,
          retentionCount: 5,
        );
        await db.upsertBackupRecord(
          fileName: 'only.json',
          uri: 'content://only',
          sizeBytes: 1,
          createdAt: DateTime(2026, 8, 5),
        );
        expect(await db.staleBackupRecords(), isEmpty);
      },
    );

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
