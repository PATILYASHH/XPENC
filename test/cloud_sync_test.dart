import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/features/data_export/cloud_sync_models.dart';
import 'package:xpenc/features/data_export/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => db.close());

  test('CloudSyncService defaults to offline (none) and autoSync true', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);

    expect(service.provider, CloudSyncProvider.none);
    expect(service.autoSync, isTrue);
    expect(service.lastSyncedAt, isNull);
    expect(service.githubToken, isEmpty);
    expect(service.githubRepo, isEmpty);
    expect(service.githubBranch, 'main');
  });

  test('setting provider updates state and persists to SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);

    await service.setProvider(CloudSyncProvider.gdrive);
    expect(service.provider, CloudSyncProvider.gdrive);

    // Verify it reloads correctly from prefs
    final reloaded = CloudSyncService(db, prefs);
    expect(reloaded.provider, CloudSyncProvider.gdrive);

    await service.setProvider(CloudSyncProvider.connector);
    expect(service.provider, CloudSyncProvider.connector);
  });

  test('saving connector config persists repository and token', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);

    await service.saveConnectorConfig(
      token: 'ghp_test123456',
      repo: 'testuser/xpenc-sync',
      branch: 'sync-branch',
    );

    expect(service.githubToken, 'ghp_test123456');
    expect(service.githubRepo, 'testuser/xpenc-sync');
    expect(service.githubBranch, 'sync-branch');

    final reloaded = CloudSyncService(db, prefs);
    expect(reloaded.githubToken, 'ghp_test123456');
    expect(reloaded.githubRepo, 'testuser/xpenc-sync');
    expect(reloaded.githubBranch, 'sync-branch');
  });

  test('saving github config persists repository and token', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);

    await service.saveGithubConfig(
      token: 'ghp_test123456',
      repo: 'testuser/xpenc-sync',
      branch: 'sync-branch',
    );

    expect(service.githubToken, 'ghp_test123456');
    expect(service.githubRepo, 'testuser/xpenc-sync');
    expect(service.githubBranch, 'sync-branch');

    final reloaded = CloudSyncService(db, prefs);
    expect(reloaded.githubToken, 'ghp_test123456');
    expect(reloaded.githubRepo, 'testuser/xpenc-sync');
    expect(reloaded.githubBranch, 'sync-branch');
  });

  test('syncNow throws when github provider is selected but unconfigured', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);
    await service.setProvider(CloudSyncProvider.connector);

    final result = await service.syncNow();
    expect(result.type, SyncResultType.error);
    expect(result.message, contains('GitHub is not configured yet.'));
  });

  test('syncNow returns upToDate when provider is none', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);

    final result = await service.syncNow();
    expect(result.type, SyncResultType.upToDate);
    expect(result.message, contains('turned off'));
  });

  test('setAutoSync toggles and persists', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudSyncService(db, prefs);

    await service.setAutoSync(false);
    expect(service.autoSync, isFalse);

    final reloaded = CloudSyncService(db, prefs);
    expect(reloaded.autoSync, isFalse);
  });
}
