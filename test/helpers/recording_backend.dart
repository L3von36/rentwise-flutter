import 'dart:io' show Directory;

import 'package:appwrite/appwrite.dart' as aw;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:rentwise/models/account.dart';
import 'package:rentwise/models/activity_entry.dart';
import 'package:rentwise/models/customer.dart';
import 'package:rentwise/models/inventory_item.dart';
import 'package:rentwise/models/rental_order.dart';
import 'package:rentwise/services/appwrite_backend.dart';
import 'package:rentwise/state/workspace_state.dart';

import '../fixtures/sample_dataset.dart';

/// Keeps the Appwrite SDK's cookie-store init happy inside the test VM
/// (platform channels are unavailable there).
class TestPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      (await Directory.systemTemp.createTemp('rentwise-test')).path;

  @override
  Future<String?> getTemporaryPath() async =>
      (await Directory.systemTemp.createTemp('rentwise-test')).path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      (await Directory.systemTemp.createTemp('rentwise-test')).path;
}

/// MUST run before the first [RecordingBackend] is built: the
/// AppwriteBackend base constructor starts the Appwrite Client init,
/// which resolves a cookie path asynchronously — installing the shim
/// in the subclass constructor body would lose that race.
void initTestCloud() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (PathProviderPlatform.instance is! TestPathProvider) {
    PathProviderPlatform.instance = TestPathProvider();
  }
}

/// One registered appwrite account (email + password + resolved profile).
class FakeUser {
  final String email;
  final String password;
  final Account account;
  const FakeUser({
    required this.email,
    required this.password,
    required this.account,
  });
}

/// In-memory stand-in for Appwrite Cloud used by every UI/scenario test.
///
/// Production has NO offline demo fallback, so tests inject this fake
/// backend instead of touching the network. It serves a configurable
/// [WorkspaceSnapshot] (defaulting to the Riverside Events sample
/// dataset) and RECORDS every write-through call so tests can assert
/// exactly which documents the app pushed to which collection.
class RecordingBackend extends AppwriteBackend {
  RecordingBackend({List<FakeUser>? users, WorkspaceSnapshot? snapshot})
      : _users = {
          for (final u in users ??
              [
                FakeUser(
                  email: SampleDataset.demoEmployee.email,
                  password: 'employee-pass',
                  account: SampleDataset.demoEmployee,
                ),
                FakeUser(
                  email: SampleDataset.demoOwner.email,
                  password: 'owner-pass',
                  account: SampleDataset.demoOwner,
                ),
              ])
            u.email.toLowerCase(): u,
        },
        _snapshot = snapshot ?? _sampleSnapshot() {
    // Cookie-store init: initTestCloud() must already have installed
    // the temp path provider (see its doc comment).
    if (PathProviderPlatform.instance is! TestPathProvider) {
      PathProviderPlatform.instance = TestPathProvider();
    }
  }

  final Map<String, FakeUser> _users;
  final WorkspaceSnapshot _snapshot;

  /// Every write-through call the app made, in order.
  final List<RecordedWrite> writes = [];

  int authenticateCalls = 0;
  int loadCalls = 0;

  /// When true, loadWorkspace throws (simulates cloud unreachable
  /// right after a successful auth) — used to prove there is no
  /// demo fallback on the load path.
  bool failLoad = false;

  /// When true, every write-through call throws (simulates Appwrite
  /// rejecting a mutation) — used to prove the state layer SURFACES
  /// the failure instead of pretending success.
  bool failWrites = false;

  WorkspaceSnapshot get snapshot => _snapshot;

  static WorkspaceSnapshot _sampleSnapshot() {
    final now = DateTime.now();
    return WorkspaceSnapshot(
      accountUserId: 'fake-user',
      inventory: SampleDataset.inventory(),
      orders: SampleDataset.orders(now),
      customers: SampleDataset.customers(now),
      activity: SampleDataset.activity(now),
      pickups: SampleDataset.pickups(now),
      workspaces: [SampleDataset.workspaceName],
      activeWorkspace: SampleDataset.workspaceName,
      grossMonthK: SampleDataset.grossRevenueMonth,
      utilizationPct: SampleDataset.utilizationPct,
      earnings: SampleDataset.earningsDaily(now),
      categoryRevenue: SampleDataset.categoryRevenue,
      trend: SampleDataset.revenueTrend(now),
    );
  }

  @override
  Future<Account> authenticate(String email, String password) async {
    authenticateCalls++;
    // Small latency so the UI's loading spinner is exercisable.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final u = _users[email.trim().toLowerCase()];
    if (u == null || u.password != password) {
      throw aw.AppwriteException(
          'Invalid credentials. Email or password is incorrect.',
          401,
          'user_invalid_credentials');
    }
    return u.account;
  }

  /// Mirrors the real backend's sign-up + bootstrap rule: the FIRST
  /// account when no owner exists becomes the owner, everyone after
  /// that joins as an employee. Duplicate emails throw like the cloud.
  @override
  Future<Account> registerAccount(
      String name, String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw aw.AppwriteException(
          'A user with the same email already exists.', 409,
          'user_already_exists');
    }
    if (password.length < 8) {
      throw aw.AppwriteException(
          'Password must be at least 8 characters.', 400,
          'user_password_invalid');
    }
    final hasOwner = _users.values.any((u) => u.account.role == UserRole.owner);
    final account = Account(
      name: name.trim(),
      email: email.trim(),
      role: hasOwner ? UserRole.employee : UserRole.owner,
      initials: initialsFor(name.trim()),
      title: hasOwner ? 'Team member' : 'Workspace owner',
    );
    _users[key] = FakeUser(
        email: email.trim(), password: password, account: account);
    writes.add(RecordedWrite(
      collection: 'profiles',
      id: key,
      isNew: true,
      data: {'role': account.role.name, 'bootstrapOwner': !hasOwner},
    ));
    return account;
  }

  @override
  Future<void> resetWorkspaceData() async {
    writes.add(const RecordedWrite(
      collection: 'reset',
      id: 'all-business-collections',
      isNew: false,
      data: {},
    ));
  }

  @override
  Future<WorkspaceSnapshot> loadWorkspace() async {
    loadCalls++;
    if (failLoad) {
      throw aw.AppwriteException('network unreachable', 0,
          'general_network_error');
    }
    return _snapshot;
  }

  @override
  Future<void> signOutAccount() async {}

  @override
  Future<void> putInventoryItem(InventoryItem item, {bool isNew = false}) =>
      _record('inventory', item.id, isNew, extra: {
        'available': item.available,
        'maintenance': item.maintenance,
      });

  @override
  Future<void> putOrder(RentalOrder order, {bool isNew = false}) =>
      _record('orders', order.id, isNew,
          extra: {'status': order.status.name, 'total': order.total});

  @override
  Future<void> putCustomer(Customer customer, {bool isNew = false}) =>
      _record('customers', customer.id, isNew, extra: {
        'rentals': customer.rentals,
        'lifetimeSpend': customer.lifetimeSpend,
      });

  @override
  Future<void> putActivity(ActivityEntry entry) =>
      _record('activities', entry.id, true, extra: {'body': entry.body});

  @override
  Future<void> putWorkspace(String name, {required String createdBy}) =>
      // The real backend derives the document id from the name slug —
      // record the same id it would create on the cloud.
      _record('workspaces', slugFor(name), true,
          extra: {'createdBy': createdBy});

  @override
  Future<void> setActiveWorkspace(String name) =>
      // v1.15: the active-workspace pointer lives in the user's own
      // user_prefs document (profiles are create-once, never updated).
      _record('user_prefs', 'activeWorkspace', false, extra: {'name': name});

  Future<void> _record(String collection, String id, bool isNew,
      {Map<String, Object?>? extra}) async {
    if (failWrites) {
      throw aw.AppwriteException('cloud rejected mutation', 400,
          'general_rate_limit_exceeded');
    }
    writes.add(RecordedWrite(
      collection: collection,
      id: id,
      isNew: isNew,
      data: extra ?? const {},
    ));
  }
}

/// A single write-through call captured by [RecordingBackend].
class RecordedWrite {
  final String collection;
  final String id;
  final bool isNew;
  final Map<Object?, Object?> data;

  const RecordedWrite({
    required this.collection,
    required this.id,
    required this.isNew,
    required this.data,
  });

  @override
  String toString() => 'RecordedWrite($collection/$id isNew=$isNew $data)';
}

/// Convenience: signs [email] in on [state] through the real code path.
Future<String?> signInWith(WorkspaceState state, String email,
        String password) =>
    state.signInWithEmail(email, password);
