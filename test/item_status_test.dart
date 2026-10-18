import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwrite/models.dart' as models;
import 'package:rentwise/models/inventory_item.dart';
import 'package:rentwise/services/appwrite_backend.dart';
import 'package:rentwise/state/workspace_state.dart';

import 'helpers/recording_backend.dart';
import 'fixtures/sample_dataset.dart';

/// Item-status semantics, the maintenance lifecycle, the registration
/// (sign-up) flow and the owner danger-zone reset — all against the
/// in-memory Appwrite stand-in with write-through assertions.
void main() {
  initTestCloud();

  InventoryItem item({
    int totalStock = 10,
    int available = 10,
    bool maintenance = false,
    String id = 'INV-T',
  }) =>
      InventoryItem(
        id: id,
        name: 'Test Item',
        note: '',
        category: 'Seating',
        totalStock: totalStock,
        available: available,
        maintenance: maintenance,
        ratePerDay: 5,
        icon: Icons.inventory_2_outlined,
      );

  // ------------------------------------------------------ status rules
  group('ITEM STATUS — derivation rules', () {
    test('all units free -> In stock', () {
      expect(item(available: 10).status, ItemStatus.inStock);
    });

    test('some out, some free -> Partially out', () {
      expect(item(available: 4, totalStock: 10).status, ItemStatus.partial);
    });

    test('every unit out -> Rented out (never mislabelled Maintenance)',
        () {
      final i = item(available: 0, totalStock: 10);
      expect(i.status, ItemStatus.rentedOut);
      expect(i.status, isNot(ItemStatus.maintenance));
    });

    test('operator flag wins -> Maintenance even with free units', () {
      final i = item(available: 6, totalStock: 10, maintenance: true);
      expect(i.status, ItemStatus.maintenance);
      expect(i.needsAttention, isTrue);
    });

    test('on-rent units never count maintenance stock', () {
      expect(item(available: 0, totalStock: 10).onRentUnits, 10);
      expect(
        item(available: 0, totalStock: 10, maintenance: true).onRentUnits,
        0,
        reason: 'a broken chair is not on rent',
      );
    });
  });

  // ------------------------------------------ workspace KPI integration
  group('ITEM STATUS — live KPIs & filters (owner session)', () {
    late RecordingBackend backend;
    late WorkspaceState state;

    setUp(() async {
      backend = RecordingBackend();
      state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');
    });

    test('sample dataset: 496 total, maintenance linens excluded from '
        'available and on-rent pools', () {
      // Riverside sample: 6 lines, 496 units, linens (120) in maintenance.
      expect(state.totalUnits, 496);
      expect(state.attentionItems, 1);

      // Available = 190 + 12 + 64 + 3 + 6 = 275 (linen excluded).
      expect(state.availableUnits, 275);
      // On rent = 50 + 36 + 5 + 10 = 101 (linen excluded — it is not
      // with a customer, it is being cleaned).
      expect(state.onRentUnits, 101);
    });

    test('marking maintenance updates KPIs and writes the flag through',
        () async {
      final chairs = state.inventory
          .firstWhere((i) => i.name == 'Folding Chairs');

      state.adjustStock(chairs, maintenance: true);
      expect(state.attentionItems, 2);
      // Chairs (50 out) leave the on-rent pool, availability unchanged.
      expect(state.onRentUnits, 101 - 50);
      expect(state.availableUnits, 275 - 190);

      final write = backend.writes.lastWhere(
          (w) => w.collection == 'inventory' && w.id == chairs.id);
      expect(write.data['maintenance'], isTrue);

      // Back to service — everything returns to the pools.
      state.adjustStock(
          state.inventory.firstWhere((i) => i.id == chairs.id),
          maintenance: false);
      expect(state.onRentUnits, 101);
      final revert = backend.writes.lastWhere(
          (w) => w.collection == 'inventory' && w.id == chairs.id);
      expect(revert.data['maintenance'], isFalse);
    });

    test('status chips narrow the table — counts stay live', () {
      // Chairs 190/240, tables 12/48, bar 3/8, heaters 6/16 -> partial;
      // lights 64/64 -> in stock; linens flagged -> maintenance.
      expect(state.countByStatus(ItemStatus.inStock), 1);
      expect(state.countByStatus(ItemStatus.partial), 4);
      expect(state.countByStatus(ItemStatus.rentedOut), 0);
      expect(state.countByStatus(ItemStatus.maintenance), 1);

      state.setInventoryStatusFilter(ItemStatus.partial);
      expect(state.filteredInventory.length, 4);
      expect(
        state.filteredInventory.every((i) => i.status == ItemStatus.partial),
        isTrue,
      );

      state.setInventoryStatusFilter(ItemStatus.maintenance);
      expect(state.filteredInventory.single.name, 'White Linen 90"');

      // Tap the active chip again — filter clears.
      state.setInventoryStatusFilter(ItemStatus.maintenance);
      state.setInventoryStatusFilter(null);
      expect(state.filteredInventory.length, 6);
    });
  });

  // ------------------------------------------------------- registration
  group('REGISTRATION — sign-up flow', () {
    test('fresh cloud with no owner: first registrant becomes OWNER and '
        'gets a starter workspace', () async {
      // A brand-new cloud: no accounts, no workspaces yet.
      final backend = RecordingBackend(
        users: [],
        snapshot: const WorkspaceSnapshot(
          accountUserId: 'fake-user',
          inventory: [],
          orders: [],
          customers: [],
          activity: [],
          pickups: [],
          workspaces: [],
          activeWorkspace: '',
          grossMonthK: 0,
          utilizationPct: 0,
          earnings: [],
          categoryRevenue: [],
          trend: [],
        ),
      );
      final state = WorkspaceState(backend: backend);

      final err = await state.signUpWithEmail(
          'Nova Owner', 'nova@example.com', 'strong-pass-1');
      expect(err, isNull);
      expect(state.isSignedIn, isTrue);
      expect(state.isOwner, isTrue);
      expect(state.workspace, "Nova's Workspace");
      expect(state.workspaces, ["Nova's Workspace"]);
      // Starter workspace went to the cloud too.
      expect(
        backend.writes.where((w) => w.collection == 'workspaces'),
        isNotEmpty,
      );
      final reg = backend.writes.firstWhere(
          (w) => w.collection == 'profiles' && w.id == 'nova@example.com');
      expect(reg.data['role'], 'owner');
    });

    test('cloud WITH an owner: self-registration is CLOSED — employees '
        'are created by the owner instead', () async {
      final backend = RecordingBackend(); // demo owner pre-registered
      final state = WorkspaceState(backend: backend);

      final err = await state.signUpWithEmail(
          'Sam Staff', 'sam@example.com', 'strong-pass-2');
      expect(err, isNotNull, reason: 'registration must be refused');
      expect(err, contains('Registration is closed'));
      expect(err, contains('owner'));
      expect(state.isSignedIn, isFalse);
      expect(state.canAccess(Section.reports), isFalse);
      expect(state.canAccess(Section.access), isFalse);
      // No profile was written for the refused sign-up.
      expect(
        backend.writes.where(
            (w) => w.collection == 'profiles' && w.id == 'sam@example.com'),
        isEmpty,
      );
    });

    test('duplicate email surfaces a friendly error and stays on auth',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);

      final err = await state.signUpWithEmail('Copy Cat',
          SampleDataset.demoOwner.email, 'strong-pass-3');
      expect(err, isNotNull);
      expect(state.isSignedIn, isFalse);
    });

    test('weak password is rejected before any profile is written',
        () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);

      final err =
          await state.signUpWithEmail('Shorty', 's@example.com', 'short');
      expect(err, isNotNull);
      expect(
        backend.writes.where(
            (w) => w.collection == 'profiles' && w.id == 's@example.com'),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------- danger zone
  group('DANGER ZONE — reset workspace data', () {
    test('owner reset wipes every business list, zeroes metrics and '
        'records the cloud reset', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoOwner.email, 'owner-pass');

      await state.resetWorkspaceData();

      expect(state.inventory, isEmpty);
      expect(state.orders, isEmpty);
      expect(state.customers, isEmpty);
      expect(state.activity, isNotEmpty, reason: 'the reset note is logged');
      expect(state.totalUnits, 0);
      expect(state.monthGrossRevenueK, 0);
      expect(state.utilization, 0);
      expect(
        backend.writes.any((w) => w.collection == 'reset'),
        isTrue,
      );
      // The workspace itself survives a reset.
      expect(state.workspace, 'Riverside Events');
    });

    test('employees can never reset — the call is a no-op', () async {
      final backend = RecordingBackend();
      final state = WorkspaceState(backend: backend);
      await state.signInWithEmail(
          SampleDataset.demoEmployee.email, 'employee-pass');

      await state.resetWorkspaceData();

      expect(state.inventory.length, 6);
      expect(backend.writes.where((w) => w.collection == 'reset'), isEmpty);
    });
  });

  // --------------------------------------- backend decode compatibility
  group('BACKEND — maintenance attribute decode', () {
    test('documents without the flag decode as NOT in maintenance', () {
      final i = AppwriteBackend.inventoryFromDoc(
        _doc(const {
          'name': 'Old Row',
          'note': '',
          'category': 'Seating',
          'totalStock': 5,
          'available': 2,
          'ratePerDay': 3,
        }),
      );
      expect(i.maintenance, isFalse);
      expect(i.status, ItemStatus.partial);
    });

    test('explicit maintenance flag decodes', () {
      final i = AppwriteBackend.inventoryFromDoc(
        _doc(const {
          'name': 'Broken Row',
          'category': 'Seating',
          'totalStock': 5,
          'available': 5,
          'maintenance': true,
          'ratePerDay': 3,
        }),
      );
      expect(i.maintenance, isTrue);
      expect(i.status, ItemStatus.maintenance);
    });
  });
}

/// Builds a real appwrite models.Document for the decode tests.
models.Document _doc(Map<String, dynamic> data) => models.Document(
      $id: 'fake-doc-id',
      $sequence: 0,
      $collectionId: 'inventory_items',
      $databaseId: 'rentwise-db',
      $createdAt: '2026-01-01T00:00:00.000Z',
      $updatedAt: '2026-01-01T00:00:00.000Z',
      $permissions: const [],
      data: data,
    );
