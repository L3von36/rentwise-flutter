// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:rentwise/models/account.dart';
import 'package:rentwise/services/appwrite_backend.dart';

/// Points the Appwrite SDK's cookie store at a writable temp directory.
///
/// In the test VM the real path_provider resolves to paths that may not
/// exist, which makes the SDK's init() fail and every request then waits
/// on `_initialized` forever. A fake keeps the probe honest: everything
/// else (auth, permissions, documents) runs against the real Cloud.
class _TempPathProvider extends PathProviderPlatform {
  /// Each Appwrite Client instance gets its OWN cookie directory — sharing
  /// one PersistCookieJar across clients would leak the first account's
  /// session into the second login.
  static int _n = 0;

  _TempPathProvider(this.root);
  final String root;

  String get _next => '$root/instance-${_n++}';

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final d = Directory(_next);
    await d.create(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getTemporaryPath() async => _next;

  @override
  Future<String?> getApplicationSupportPath() async => _next;
}

/// Live end-to-end login probe against Appwrite Cloud.
///
/// Exercises the EXACT code path the sign-in screen uses:
///   AppwriteBackend().authenticate(email, password) -> loadWorkspace()
///
/// Run with (CI-safe — skips without the env var):
///   AW_E2E=1 flutter test test/live_login_test.dart
void main() {
  final enabled = Platform.environment['AW_E2E'] == '1';
  final tmp = Directory.systemTemp.createTempSync('rentwise_live_probe');
  PathProviderPlatform.instance = _TempPathProvider(tmp.path);

  test('authenticate + loadWorkspace against Appwrite Cloud',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    if (!enabled) {
      print('AW_E2E not set — skipping live login probe.');
      return;
    }
    final backend = AppwriteBackend();
    print('[probe] backend constructed — calling authenticate()…');

    // 1) Owner sign-in — same call the sign-in screen makes.
    final account = await backend.authenticate(
      'selamvenda8@gmail.com',
      'selam@336',
    );
    print('[probe] auth OK: ${account.name} (${account.email}) '
        'role=${account.role}');

    // 2) Full workspace load — same call the shell makes after sign-in.
    print('[probe] calling loadWorkspace()…');
    final snap = await backend.loadWorkspace();
    print('workspace "${snap.activeWorkspace}": '
        '${snap.inventory.length} items, ${snap.orders.length} orders, '
        '${snap.customers.length} customers, ${snap.activity.length} '
        'activities, ${snap.workspaces.length} workspaces');

    expect(account.role, UserRole.owner,
        reason: 'owner account must resolve the owner role');
    expect(snap.orders, isNotEmpty, reason: 'seeded orders must load');
    expect(snap.customers, isNotEmpty, reason: 'seeded customers must load');
    expect(snap.inventory, isNotEmpty, reason: 'seeded inventory must load');

    // 3) Employee sign-in — role separation check.
    final emp = AppwriteBackend();
    final empAccount = await emp.authenticate(
      'jordan@riverside.events',
      'jordan@336',
    );
    print('auth OK: ${empAccount.name} role=${empAccount.role}');
    expect(empAccount.role, UserRole.employee,
        reason: 'employee account must resolve the employee role');
  });
}
