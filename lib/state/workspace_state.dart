import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../core/palette.dart';
import '../data/appwrite_mappers.dart';
import '../data/catalog.dart';
import '../models/account.dart';
import '../models/activity_entry.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/pickup.dart';
import '../models/rental_order.dart';
import '../models/shift_task.dart';
import '../services/appwrite_backend.dart';
import '../core/app_locale.dart';

/// Workspace sections (sidebar / drawer destinations).
enum Section { dashboard, inventory, orders, customers, activity, access, reports }

extension SectionX on Section {
  String get label => switch (this) {
        Section.dashboard => AppLocale.t('Dashboard'),
        Section.inventory => AppLocale.t('Inventory'),
        Section.orders => AppLocale.t('Orders'),
        Section.customers => AppLocale.t('Customers'),
        Section.activity => AppLocale.t('Activity Log'),
        Section.access => AppLocale.t('Access & roles'),
        Section.reports => AppLocale.t('Reports'),
      };

  String get breadcrumb => switch (this) {
        Section.dashboard => AppLocale.t('Operations overview'),
        Section.inventory => AppLocale.t('Inventory'),
        Section.orders => AppLocale.t('Orders'),
        Section.customers => AppLocale.t('Customers'),
        Section.activity => AppLocale.t('Activity Log'),
        Section.access => AppLocale.t('Access & roles'),
        Section.reports => AppLocale.t('Reports'),
      };
}

/// Booking line inside the new-rental-booking sheet.
class BookingLine {
  final InventoryItem item;
  int qty;
  BookingLine({required this.item, this.qty = 1});
}

/// A one-shot UI notice (snackbar). Permission denials and cloud write
/// failures are EMITTED, never swallowed silently.
class StateNotice {
  final int id;
  final String message;
  final bool isError;
  const StateNotice(this.id, this.message, {this.isError = false});
}

/// Single source of truth for the whole workspace.
///
/// One store keeps cross-screen reactions trivial:
/// creating a booking decrements availability, appends an order,
/// writes an activity entry and bumps the sidebar badge.
///
/// Appwrite Cloud is the ONLY data source: sign-in loads the live
/// workspace and every mutation is written through to the cloud.
/// There is no offline/demo fallback — until a sign-in succeeds the
/// store is simply empty, and if the backend is unreachable sign-in
/// fails with an error and the UI stays on the auth screen.
class WorkspaceState extends ChangeNotifier {
  WorkspaceState({AppwriteBackend? backend}) : _backend = backend {
    _inventory = const [];
    _orders = const [];
    _customers = const [];
    _activity = const [];
    _pickups = const [];
    _earnings = const [];
    _trend = const [];
  }

  final AppwriteBackend? _backend;

  // ----------------------------------------------------------- notices
  int _noticeSeq = 0;

  /// Latest snackbar-worthy event (permission denial, cloud write
  /// failure). UI consumers compare [StateNotice.id] to avoid re-showing
  /// the same notice on rebuild.
  StateNotice? lastNotice;

  void _emit(String message, {bool error = false}) {
    lastNotice = StateNotice(++_noticeSeq, message, isError: error);
  }

  /// Emits the standard owner-only denial — restrictions are never
  /// silent (user-facing restrictions rule).
  void _deny(String action) {
    _emit(
      'Owner access required — "$action" is managed by the workspace owner.',
      error: true,
    );
  }

  /// Fire-and-forget persistence — the local store stays the UI truth;
  /// Appwrite failures are surfaced as an error notice instead of being
  /// silently dropped (never pretend a failed write succeeded).
  void _push(Future<void> work, String label) {
    work.catchError((Object e) {
      debugPrint('Appwrite[$label] $e');
      _emit('Cloud sync failed ($label) — change is local only. '
          'Check your connection; it will not be re-sent automatically.',
          error: true);
      notifyListeners();
    });
  }

  // -------------------------------------------------------------- workspace
  /// Populated from the cloud `workspaces` collection at sign-in; empty
  /// until then (nothing is bundled or invented locally).
  final List<String> _workspaces = [];
  String _workspace = '';

  List<String> get workspaces => List.unmodifiable(_workspaces);
  String get workspace => _workspace;

  /// True when this workspace is the one being viewed.
  bool get isSingleWorkspace => _workspaces.length == 1;

  /// Switches the active workspace (owner-only — employees work in the
  /// single workspace the owner assigned them to).
  void switchWorkspace(String name) {
    if (!role.canManageWorkspaces) {
      _deny('switch workspace');
      notifyListeners();
      return;
    }
    if (!_workspaces.contains(name) || name == _workspace) return;
    _workspace = name;
    _backend?.setActiveWorkspace(name);
    _log(
      type: ActivityType.note,
      body: '**${_account?.name ?? 'Someone'}** switched to workspace **$name**',
    );
    notifyListeners();
  }

  /// Creates and switches to a new workspace (owner-only). Returns
  /// false when the name is empty, taken, or the role lacks permission.
  bool addWorkspace(String name) {
    if (!role.canManageWorkspaces) {
      _deny('create workspace');
      notifyListeners();
      return false;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || _workspaces.contains(trimmed)) return false;
    _workspaces.add(trimmed);
    _workspace = trimmed;
    final b = _backend;
    if (b != null) {
      _push(
          b.putWorkspace(trimmed, createdBy: _account?.name ?? ''),
          'workspaces.put');
      _push(b.setActiveWorkspace(trimmed), 'workspaces.active');
    }
    _log(
      type: ActivityType.note,
      body:
          '**${_account?.name ?? 'Someone'}** created workspace **$trimmed**',
    );
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------- auth
  Account? _account;
  bool _loadingAuth = false;
  String? _authError;

  Account? get account => _account;
  bool get isSignedIn => _account != null;
  bool get loadingAuth => _loadingAuth;
  String? get authError => _authError;
  bool get liveBackend => _backend != null;
  UserRole get role => _account?.role ?? UserRole.employee;
  bool get isOwner => role == UserRole.owner;

  /// Real sign-up against Appwrite — the ONE-TIME owner bootstrap.
  /// Creates the account, signs it in and writes the owner profile.
  /// Registration is refused once the workspace has an owner
  /// ([RegistrationClosedException] surfaces through the auth error):
  /// employee accounts are created by the owner afterwards via
  /// [addEmployee], never by self-service sign-up. Returns null on
  /// success.
  Future<String?> signUpWithEmail(
      String name, String email, String password) async {
    final b = _backend;
    _loadingAuth = true;
    _authError = null;
    notifyListeners();
    try {
      if (b == null) {
        _loadingAuth = false;
        _authError =
            'Appwrite backend is not configured in this build. '
            'Please reinstall the official release.';
        notifyListeners();
        return _authError;
      }
      _account = await b.registerAccount(name.trim(), email.trim(), password);
      final snap = await b.loadWorkspace();
      _adoptSnapshot(snap);
      _ensureOwnerWorkspace();
      await loadTeam();
      _loadingAuth = false;
      _section = Section.dashboard;
      notifyListeners();
      return null;
    } catch (e) {
      _account = null;
      _loadingAuth = false;
      _authError = AppwriteBackend.authErrorText(e);
      notifyListeners();
      return _authError;
    }
  }

  /// Replaces the whole store with exactly what the cloud returned.
  void _adoptSnapshot(WorkspaceSnapshot snap) {
    _inventory = snap.inventory;
    _orders = snap.orders;
    _customers = snap.customers;
    _activity = snap.activity;
    _pickups = snap.pickups;
    _workspaces
      ..clear()
      ..addAll(snap.workspaces);
    if (snap.activeWorkspace.isNotEmpty &&
        _workspaces.contains(snap.activeWorkspace)) {
      _workspace = snap.activeWorkspace;
    } else if (_workspaces.isNotEmpty) {
      _workspace = _workspaces.first;
    } else {
      _workspace = '';
    }
    _earnings = snap.earnings;
    _trend = snap.trend;
    _categoryRevenue = snap.categoryRevenue;
    _grossMonthK = snap.grossMonthK;
    _utilizationPct = snap.utilizationPct;
    // Fresh data, fresh filters — never inherit a stale narrowing.
    _categoryFilter = Catalog.allCategories;
    _inventoryQuery = '';
    _inventoryStatusFilter = null;
  }

  /// After a bootstrap-owner sign-in/up: a brand-new cloud has no
  /// workspace yet, so give the owner theirs immediately instead of an
  /// empty picker.
  void _ensureOwnerWorkspace() {
    if (!isOwner || _workspaces.isNotEmpty) return;
    final first = _account?.name.trim().split(' ').first ?? 'My';
    final name = first.isEmpty ? 'My Workspace' : "$first's Workspace";
    final ok = addWorkspace(name);
    if (ok) return;
    addWorkspace('My Workspace');
  }

  /// Real sign-in against Appwrite. Returns null on success or a
  /// human-friendly error message the auth screen can display.
  Future<String?> signInWithEmail(String email, String password) async {
    final b = _backend;
    _loadingAuth = true;
    _authError = null;
    notifyListeners();
    try {
      if (b == null) {
        // Production builds always inject an AppwriteBackend (main.dart).
        // Reaching this means a wiring bug — fail honestly instead of
        // falling back to any local dataset.
        _loadingAuth = false;
        _authError =
            'Appwrite backend is not configured in this build. '
            'Please reinstall the official release.';
        notifyListeners();
        return _authError;
      }
      _account = await b.authenticate(email, password);
      final snap = await b.loadWorkspace();
      // Replace the store with EXACTLY what Cloud returns — an empty
      // collection shows an empty workspace. Nothing is invented locally.
      _adoptSnapshot(snap);
      _ensureOwnerWorkspace();
      await loadTeam();
      _loadingAuth = false;
      _section = Section.dashboard;
      notifyListeners();
      return null;
    } catch (e) {
      // Auth or load failed — roll the account back so the user stays
      // on the auth screen instead of entering an empty workspace.
      _account = null;
      _loadingAuth = false;
      _authError = AppwriteBackend.authErrorText(e);
      notifyListeners();
      return _authError;
    }
  }

  /// Switch role in place (used by the owner-only Access & roles screen).
  ///
  /// Owners may switch to the employee role to preview their view;
  /// employees can never promote themselves — only owners manage access.
  /// The real signed-in identity is kept — only the effective role flips,
  /// locally, for the session. Revert by signing out and back in.
  void switchRole(UserRole role) {
    if (!isOwner) return;
    if (_account == null || _account!.role == role) return;
    _account = _account!.copyWith(role: role);
    if (!isOwner &&
        (section == Section.reports || section == Section.access)) {
      _section = Section.dashboard; // preview lands somewhere allowed
    }
    notifyListeners();
  }

  void signOut() {
    _backend?.signOutAccount();
    _account = null;
    _section = Section.dashboard;
    _team = const [];
    notifyListeners();
  }

  // ---------------------------------------------------------------- team
  /// Every workspace member (owner first). Loaded from the cloud
  /// `profiles` collection for the OWNER only — employees never see the
  /// team console and accounts are created exclusively by the owner.
  List<Account> _team = const [];
  bool _loadingTeam = false;

  List<Account> get team => List.unmodifiable(_team);
  bool get loadingTeam => _loadingTeam;

  /// Loads the team directory (owner-only). Failures surface as an
  /// error notice but never block the sign-in flow.
  Future<void> loadTeam() async {
    final b = _backend;
    if (b == null || !isOwner) return;
    _loadingTeam = true;
    notifyListeners();
    try {
      _team = await b.listTeam();
    } catch (e) {
      debugPrint('Appwrite[profiles.list] $e');
      _emit('Could not load the team list — check your connection.',
          error: true);
    }
    _loadingTeam = false;
    notifyListeners();
  }

  /// OWNER ACTION — creates an employee account end-to-end (Appwrite
  /// auth account + employee profile). This is the ONLY way employee
  /// accounts come into existence: self-registration is closed once
  /// the workspace has an owner.
  ///
  /// Returns null on success, or a human-friendly error message.
  Future<String?> addEmployee({
    required String name,
    required String email,
    required String password,
    String title = 'Team member',
  }) async {
    if (!isSignedIn) return 'Sign in first.';
    if (!role.canManageTeam) {
      _deny('create employee accounts');
      notifyListeners();
      return 'Owner access required — employee accounts are managed by '
          'the workspace owner.';
    }
    final b = _backend;
    if (b == null) {
      return 'Appwrite backend is not configured in this build.';
    }
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty) return 'Enter the employee\u2019s full name.';
    if (!trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters (Appwrite requirement).';
    }
    try {
      final member = await b.createEmployee(
        name: trimmedName,
        email: trimmedEmail,
        password: password,
        title: title,
      );
      _team = [..._team, member];
      _log(
        type: ActivityType.note,
        body: '**${_account?.name ?? 'The owner'}** created an employee '
            'account for **${member.name}** (${member.email})',
      );
      _emit('Employee account created for ${member.email} — share the '
          'credentials securely. They sign in on the Sign in screen.');
      notifyListeners();
      return null;
    } catch (e) {
      final msg = AppwriteBackend.authErrorText(e);
      _emit(msg, error: true);
      notifyListeners();
      return msg;
    }
  }

  /// Number of owner profiles in the loaded team directory.
  int get ownerCount =>
      _team.where((m) => m.role == UserRole.owner).length;

  /// OWNER ACTION — edits a team member's role and/or job title.
  /// Guardrails: owner-only, never your own role, and the last owner
  /// cannot be demoted. Returns null on success or an error message.
  Future<String?> updateTeamMember(
    Account member, {
    UserRole? newRole,
    String? title,
  }) async {
    if (!isSignedIn) return 'Sign in first.';
    if (!role.canManageTeam) {
      _deny('edit team roles');
      notifyListeners();
      return 'Owner access required — team roles are managed by the '
          'workspace owner.';
    }
    final b = _backend;
    if (b == null) {
      return 'Appwrite backend is not configured in this build.';
    }
    final isSelf = member.userId == _account?.userId;
    if (isSelf && newRole != null && newRole != member.role) {
      return 'You cannot change your own role here — ask another owner, '
          'or use the Appwrite console.';
    }
    final demotingLastOwner = member.role == UserRole.owner &&
        newRole == UserRole.employee &&
        ownerCount <= 1;
    if (demotingLastOwner) {
      return 'At least one owner must remain. Promote another member to '
          'owner first.';
    }
    try {
      final updated = await b.updateTeamMember(
        userId: member.userId,
        role: newRole,
        title: title,
      );
      _team = [
        for (final m in _team)
          if (m.userId == member.userId)
            m.copyWith(role: updated.role, title: updated.title)
          else
            m,
      ]..sort((a, b) {
          if (a.role != b.role) return a.role == UserRole.owner ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      if (newRole != null && newRole != member.role) {
        _log(
          type: ActivityType.note,
          body: newRole == UserRole.owner
              ? '**${_account?.name ?? 'The owner'}** promoted '
                  '**${member.name}** to owner'
              : '**${_account?.name ?? 'The owner'}** changed '
                  '**${member.name}**\u2019s role to employee',
        );
      }
      _emit(newRole == null
          ? 'Updated ${member.name}\u2019s job title.'
          : newRole == UserRole.owner
              ? '${member.name} is now an owner.'
              : '${member.name} is now an employee.');
      notifyListeners();
      return null;
    } catch (e) {
      final msg = _teamActionError(e);
      _emit(msg, error: true);
      notifyListeners();
      return msg;
    }
  }

  /// OWNER ACTION — resets an employee's password via the deployed
  /// reset-password Appwrite Function. Returns null on success.
  Future<String?> resetTeamMemberPassword(
      Account member, String newPassword) async {
    if (!isSignedIn) return 'Sign in first.';
    if (!role.canManageTeam) {
      _deny('reset team passwords');
      notifyListeners();
      return 'Owner access required — password resets are managed by the '
          'workspace owner.';
    }
    if (newPassword.length < 8) {
      return 'Password must be at least 8 characters (Appwrite requirement).';
    }
    final b = _backend;
    if (b == null) {
      return 'Appwrite backend is not configured in this build.';
    }
    try {
      await b.resetTeamMemberPassword(
        userId: member.userId,
        newPassword: newPassword,
      );
      _log(
        type: ActivityType.note,
        body: '**${_account?.name ?? 'The owner'}** reset the password for '
            '**${member.name}**',
      );
      _emit('Password reset for ${member.name} — share it securely. '
          'They can change it afterwards from their Profile.');
      notifyListeners();
      return null;
    } catch (e) {
      final msg = _teamActionError(e);
      _emit(msg, error: true);
      notifyListeners();
      return msg;
    }
  }

  /// SELF-SERVICE — rotates the signed-in user's own password. Returns
  /// null on success or a human-friendly error message.
  Future<String?> changeMyPassword(
      String currentPassword, String newPassword) async {
    final b = _backend;
    if (b == null) {
      return 'Appwrite backend is not configured in this build.';
    }
    if (newPassword.length < 8) {
      return 'Password must be at least 8 characters (Appwrite requirement).';
    }
    try {
      await b.changeMyPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _emit('Password updated.');
      notifyListeners();
      return null;
    } catch (e) {
      var msg = AppwriteBackend.authErrorText(e);
      if (msg == 'Email or password is incorrect.') {
        msg = 'Current password is incorrect.';
      }
      _emit(msg, error: true);
      notifyListeners();
      return msg;
    }
  }

  /// Maps team-action failures to actionable messages (permission model
  /// not migrated yet, missing function deployment, network…).
  String _teamActionError(Object e) {
    final raw = e.toString();
    if (raw.contains('StateError')) {
      return raw.startsWith('StateError: ')
          ? raw.substring('StateError: '.length)
          : raw.replaceFirst(RegExp(r'^Bad state: '), '');
    }
    return AppwriteBackend.authErrorText(e);
  }

  // ------------------------------------------------------------------ access
  /// Sections an employee may open. The owner role has access to
  /// everything — employees work for the owner and never see business
  /// finances, the permission console or workspace settings.
  static const Set<Section> _employeeSections = {
    Section.dashboard,
    Section.inventory,
    Section.orders,
    Section.customers,
    Section.activity,
  };

  /// Single source of truth for section-level permissions.
  bool canAccess(Section s) => isOwner || _employeeSections.contains(s);

  // -------------------------------------------------------------- navigation
  Section _section = Section.dashboard;

  Section get section => _section;

  void navigate(Section s) {
    if (!isSignedIn) return;
    if (!canAccess(s)) return; // owner-only areas stay locked
    if (_section == s) return;
    _section = s;
    if (s == Section.activity) _unreadActivity = 0;
    notifyListeners();
  }

  /// Marks every activity entry as read (notifications → “Mark all read”).
  void markActivityRead() {
    if (_unreadActivity == 0) return;
    _unreadActivity = 0;
    notifyListeners();
  }

  // ------------------------------------------------------------- lookups
  RentalOrder? orderById(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Customer? customerByName(String name) {
    for (final c in _customers) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    return null;
  }

  /// Orders that belong to a customer (matched on the customer name).
  List<RentalOrder> ordersForCustomer(String name) => _orders
      .where((o) => o.customerName.toLowerCase() == name.toLowerCase())
      .toList();

  /// Today's shift tasks, derived from live order + pickup data. Shared
  /// by the employee dashboard and the Tasks screen.
  List<ShiftTask> shiftTasks(DateTime now) {
    final tasks = <ShiftTask>[];
    for (final o in _orders) {
      switch (o.status) {
        case OrderStatus.preparing:
          tasks.add(ShiftTask(
            title: 'Stage & pack',
            meta: '#${o.id} · ${o.eventName} · ${Fmt.items(o.itemCount)}',
            chip: 'Prep',
            chipFg: AppPalette.amber,
            chipBg: AppPalette.amberBg,
            kind: 'prep',
            orderId: o.id,
          ));
        case OrderStatus.outForDelivery:
          tasks.add(ShiftTask(
            title: 'Expect return',
            meta: '#${o.id} · ${o.eventName} · ${o.contactName}',
            chip: 'With customer',
            chipFg: AppPalette.blue,
            chipBg: AppPalette.blueBg,
            kind: 'delivery',
            orderId: o.id,
          ));
        case OrderStatus.needsPayment:
          tasks.add(ShiftTask(
            title: 'Collect payment',
            meta: '#${o.id} · ${o.eventName} · ${Fmt.moneySmart(o.total)}',
            chip: 'Payment',
            chipFg: AppPalette.purple,
            chipBg: AppPalette.purpleBg,
            kind: 'payment',
            orderId: o.id,
          ));
        case OrderStatus.confirmed:
        case OrderStatus.returned:
          break;
      }
    }
    for (final p in _pickups.take(2)) {
      tasks.add(ShiftTask(
        title: 'Pull & stage',
        meta:
            '${Fmt.items(p.itemCount)} · ${p.venue} · #${p.id}',
        chip: 'Upcoming',
        chipFg: AppPalette.green,
        chipBg: AppPalette.greenBg,
        kind: 'prep',
        pickupId: p.id,
      ));
    }
    return tasks;
  }

  // -------------------------------------------------------------- inventory
  late List<InventoryItem> _inventory;
  String _categoryFilter = Catalog.allCategories;
  String _inventoryQuery = '';
  ItemStatus? _inventoryStatusFilter; // null = every status

  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  String get categoryFilter => _categoryFilter;
  String get inventoryQuery => _inventoryQuery;
  ItemStatus? get inventoryStatusFilter => _inventoryStatusFilter;

  List<InventoryItem> get filteredInventory {
    Iterable<InventoryItem> items = _inventory;
    if (_categoryFilter != Catalog.allCategories) {
      items = items.where((i) => i.category == _categoryFilter);
    }
    final statusFilter = _inventoryStatusFilter;
    if (statusFilter != null) {
      items = items.where((i) => i.status == statusFilter);
    }
    if (_inventoryQuery.trim().isNotEmpty) {
      final q = _inventoryQuery.trim().toLowerCase();
      items = items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q));
    }
    return items.toList();
  }

  /// Live count per status — feeds the inventory status chips.
  int countByStatus(ItemStatus s) =>
      _inventory.where((i) => i.status == s).length;

  void setCategoryFilter(String c) {
    _categoryFilter = c;
    notifyListeners();
  }

  void setInventoryQuery(String q) {
    _inventoryQuery = q;
    notifyListeners();
  }

  /// Tapping the active status chip again clears the filter (null).
  void setInventoryStatusFilter(ItemStatus? status) {
    _inventoryStatusFilter = status;
    notifyListeners();
  }

  /// KPI: every unit the business owns, including units currently under
  /// maintenance (they are still property — see the 4th card for how
  /// many of them are out of service).
  int get totalUnits =>
      _inventory.fold(0, (sum, i) => sum + i.totalStock);

  /// KPI: units bookable right now. Maintenance items are pulled from
  /// the pool — their units are neither available nor on rent.
  int get availableUnits => _inventory
      .where((i) => !i.maintenance)
      .fold(0, (sum, i) => sum + i.available.clamp(0, i.totalStock));

  /// KPI: units out with customers. Maintenance items never count —
  /// a broken chair is not "on rent".
  int get onRentUnits =>
      _inventory.fold(0, (sum, i) => sum + i.onRentUnits);
  int get attentionItems =>
      _inventory.where((i) => i.needsAttention).length;

  /// Adds a catalog item (owner-only). Employees operate stock levels
  /// but never extend the catalog.
  void addInventoryItem({
    required String name,
    required String category,
    required int totalStock,
    required double ratePerDay,
  }) {
    if (!role.canCreateInventory) {
      _deny('add inventory items');
      notifyListeners();
      return;
    }
    final item = InventoryItem(
      id: _nextId('INV', _inventory.map((i) => i.id)),
      name: name,
      note: 'Just added',
      category: category,
      totalStock: totalStock,
      available: totalStock,
      ratePerDay: ratePerDay,
      icon: Icons.inventory_2_outlined,
    );
    _inventory = [item, ..._inventory];
    final b = _backend;
    if (b != null) {
      _push(b.putInventoryItem(item, isNew: true), 'inventory.put');
    }
    _log(
      type: ActivityType.newBooking,
      body: '**${_account?.name ?? 'Someone'}** added **$name** to inventory',
    );
    notifyListeners();
  }

  /// Adjusts stock levels and/or the maintenance hold. Operational —
  /// both roles may do it while receiving, returning or repairing.
  /// Guards the invariants: availability never negative, never above
  /// total stock, total stock never negative.
  void adjustStock(
    InventoryItem item, {
    int? totalStock,
    int? available,
    bool? maintenance,
  }) {
    if (!role.canAdjustStock) {
      _deny('adjust stock');
      notifyListeners();
      return;
    }
    final idx = _inventory.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    final ts = (totalStock ?? item.totalStock).clamp(0, 100000);
    final av = (available ?? item.available).clamp(0, ts);
    final updated = item.copyWith(
        totalStock: ts,
        available: av,
        maintenance: maintenance);
    _inventory[idx] = updated;
    final b = _backend;
    if (b != null) {
      _push(b.putInventoryItem(updated, isNew: false), 'inventory.adjust');
    }
    if (maintenance != null && maintenance != item.maintenance) {
      _log(
        type: ActivityType.note,
        body: maintenance
            ? '**${_account?.name ?? 'Someone'}** pulled **${item.name}** into maintenance'
            : '**${_account?.name ?? 'Someone'}** returned **${item.name}** to service',
      );
    }
    notifyListeners();
  }

  /// Owner-only danger action: wipes every business document from the
  /// cloud (inventory, orders, customers, activity, pickups) and zeroes
  /// the metrics document. Used to clear the bundled sample dataset and
  /// start with real data. Profiles, workspaces and the auth account
  /// are kept. Throws upward so the UI can surface an honest error.
  Future<void> resetWorkspaceData() async {
    final b = _backend;
    if (b == null || !role.canChangeSettings) {
      _deny('reset workspace data');
      notifyListeners();
      return;
    }
    await b.resetWorkspaceData();
    _inventory = const [];
    _orders = const [];
    _customers = const [];
    _activity = const [];
    _pickups = const [];
    _earnings = const [];
    _trend = const [];
    _categoryRevenue = const [];
    _grossMonthK = 0;
    _utilizationPct = 0;
    _unreadActivity = 0;
    _log(
      type: ActivityType.note,
      body:
          '**${_account?.name ?? 'Someone'}** reset the workspace — all business data was deleted',
    );
    notifyListeners();
  }

  // ----------------------------------------------------------------- orders
  late List<RentalOrder> _orders;
  String _orderTab = 'All orders';
  OrderStatus? _orderStatusFilter; // null = every status in the active tab

  List<RentalOrder> get orders => List.unmodifiable(_orders);
  String get orderTab => _orderTab;

  /// Orders in the active tab, before the status-chip filter — used for
  /// the chips' live counts so narrowing never hides the other buckets.
  List<RentalOrder> get tabOrders {
    switch (_orderTab) {
      case 'Upcoming':
        return _orders.where((o) => o.status.isUpcoming).toList();
      case 'Completed':
        return _orders.where((o) => !o.status.isUpcoming).toList();
      default:
        return List.of(_orders);
    }
  }

  OrderStatus? get orderStatusFilter => _orderStatusFilter;

  List<RentalOrder> get filteredOrders {
    final f = _orderStatusFilter;
    if (f == null) return tabOrders;
    return tabOrders.where((o) => o.status == f).toList();
  }

  int get openOrdersCount =>
      _orders.where((o) => o.status.isOpen).length;
  int get preparingCount =>
      _orders.where((o) => o.status == OrderStatus.preparing).length;
  int get needsPaymentCount =>
      _orders.where((o) => o.status == OrderStatus.needsPayment).length;
  double get awaitingPaymentTotal => outstandingMoneyTotal;
  int get outForDeliveryCount =>
      _orders.where((o) => o.status == OrderStatus.outForDelivery).length;

  /// With-customer orders whose event date is TODAY — the returns the
  /// desk should actually expect back this shift. (Counting every
  /// out-with-customer order here duplicated the "With customer" KPI
  /// and overstated the day's workload.)
  int get returnsTodayCount {
    final today = DateTime.now();
    return _orders
        .where((o) =>
            o.status == OrderStatus.outForDelivery &&
            o.eventDate.year == today.year &&
            o.eventDate.month == today.month &&
            o.eventDate.day == today.day)
        .length;
  }

  /// Out-with-customer orders whose event date has already passed —
  /// an honest "late" count derived from live data.
  int get returnsLateCount => _orders
      .where((o) =>
          o.status == OrderStatus.outForDelivery &&
          o.eventDate.isBefore(DateTime.now()))
      .length;

  /// Open orders whose event date has already passed — late returns plus
  /// anything still stuck open past its schedule. The honest "needs
  /// attention" signal for the workspace health card.
  int get openOverdueCount => _orders
      .where((o) => o.status.isOpen && o.eventDate.isBefore(DateTime.now()))
      .length;

  /// Share of open orders still on schedule (1.0 when nothing is open —
  /// nothing is overdue either). Completion timestamps don't exist yet,
  /// so this measures the live book rather than a fabricated history.
  double get scheduleHealth {
    final open = _orders.where((o) => o.status.isOpen).length;
    if (open == 0) return 1.0;
    return (open - openOverdueCount) / open;
  }

  /// Pickups scheduled for today.
  int get pickupsDueTodayCount {
    final now = DateTime.now();
    return _pickups
        .where((p) =>
            p.date.year == now.year &&
            p.date.month == now.month &&
            p.date.day == now.day)
        .length;
  }

  /// Earliest scheduled pickup — feeds the "next dispatch" surfaces.
  Pickup? get nextDispatch {
    Pickup? next;
    for (final p in _pickups) {
      if (next == null || p.date.isBefore(next.date)) next = p;
    }
    return next;
  }

  /// Customers with no booking in 30+ days — the follow-up shortlist.
  int get followUpsCount => _customers
      .where((c) => c.lastBooking
          .isBefore(DateTime.now().subtract(const Duration(days: 30))))
      .length;

  /// Day-over-day momentum of the loaded earnings series, in percent.
  double get earningsTrendPct {
    if (_earnings.length < 2) return 0;
    final prev = _earnings[_earnings.length - 2].value;
    if (prev == 0) return 0;
    return ((_earnings.last.value - prev) / prev) * 100;
  }

  void setOrderTab(String tab) {
    _orderTab = tab;
    notifyListeners();
  }

  /// Tapping the active chip again clears the filter ([status] == null).
  void setOrderStatusFilter(OrderStatus? status) {
    _orderStatusFilter = status;
    notifyListeners();
  }

  /// Moves an order to [status] (both roles operate the rental
  /// pipeline). Rejects illegal lifecycle transitions and emits an
  /// error notice — a crafted call cannot push an order backwards or
  /// into an undefined state. Returns true when the change was applied.
  ///
  /// HANDOVER GATE (v1.26 payment policy): an order can only move to
  /// [OrderStatus.outForDelivery] — i.e. the items may leave the shop —
  /// when the down payment, remaining balance and collateral are all
  /// received, the customer\'s ID is verified and the rental agreement
  /// is signed. The customer picks the items up themselves (transport
  /// is on the customer); a blocked handover emits the exact list of
  /// what is still missing.
  bool updateOrderStatus(RentalOrder order, OrderStatus status) {
    if (!role.canOperateRentals) {
      _deny('update orders');
      notifyListeners();
      return false;
    }
    if (!kOrderTransitions[order.status]!.contains(status)) {
      _emit(
        'Invalid status change — ${order.status.label} orders cannot jump '
        'straight to ${status.label}.',
        error: true,
      );
      notifyListeners();
      return false;
    }
    if (status == OrderStatus.outForDelivery && !order.canHandOver) {
      final blockers = order.handoverBlockers.join(' · ');
      _emit(
        'Handover blocked for #${order.id} — collect first: $blockers.',
        error: true,
      );
      notifyListeners();
      return false;
    }
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx == -1) return false;
    final updated = order.copyWith(status: status);
    _orders[idx] = updated;
    final b = _backend;
    if (b != null) {
      _push(b.putOrder(updated, isNew: false), 'orders.status');
    }
    _log(
      type: status == OrderStatus.returned
          ? ActivityType.returnItem
          : ActivityType.orderUpdate,
      body: '**${_account?.name ?? 'Someone'}** marked **#${order.id} · ${order.eventName}** '
          'as **${status.label}**${status == OrderStatus.confirmed ? ' (payment accepted)' : ''}',
    );
    if (status == OrderStatus.returned) {
      _emit('Order #${order.id} returned — restock items in Inventory '
          'after count/inspection. Refund the collateral deposit '
          '(${order.collateralAmount <= 0 ? 'none held' : Fmt.moneySmart(order.collateralAmount)}).');
    }
    notifyListeners();
    return true;
  }

  // -------------------------------------------------- payment policy (v1.26)
  // Down payment → remaining balance → collateral, then ID + signature —
  // ALL before the order may move to "With customer". Every action is
  // written through to the order document and logged as a payment.

  /// Applies [patch] to the live order, pushes it and logs [body].
  /// Returns the updated order, or null when blocked/not found.
  RentalOrder? _applyOrderPatch(
    RentalOrder order,
    RentalOrder Function(RentalOrder) patch, {
    required ActivityType type,
    required String body,
    String pushLabel = 'orders.payment',
  }) {
    if (!role.canOperateRentals) {
      _deny('record payments');
      notifyListeners();
      return null;
    }
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx == -1) return null;
    final updated = patch(order);
    _orders[idx] = updated;
    final b = _backend;
    if (b != null) {
      _push(b.putOrder(updated, isNew: false), pushLabel);
    }
    _log(type: type, body: body);
    notifyListeners();
    return updated;
  }

  /// Records the DOWN PAYMENT as received (always the first collection).
  /// [method] captures the Ethiopian payment rail the money arrived on.
  bool markDownPaymentReceived(RentalOrder order,
      {PaymentMethod? method}) {
    if (order.downPayment <= 0 || order.downPaymentPaidAt != null) return false;
    return _applyOrderPatch(
          order,
          (o) => o.copyWith(
              downPaymentPaidAt: DateTime.now(), downPaymentMethod: method),
          type: ActivityType.payment,
          body: '**${_account?.name ?? 'Someone'}** collected the **down payment '
              '${Fmt.moneySmart(order.downPayment)}**'
              '${method == null ? '' : ' via ${method.label}'}'
              ' on **#${order.id} · ${order.eventName}**',
        ) !=
        null;
  }

  /// Records the REMAINING balance (total − down payment) as received.
  bool markRemainingReceived(RentalOrder order, {PaymentMethod? method}) {
    if (order.remainingDue <= 0 || order.remainingPaidAt != null) return false;
    return _applyOrderPatch(
          order,
          (o) => o.copyWith(
              remainingPaidAt: DateTime.now(), remainingMethod: method),
          type: ActivityType.payment,
          body: '**${_account?.name ?? 'Someone'}** collected the **remaining '
              '${Fmt.moneySmart(order.remainingDue)}**'
              '${method == null ? '' : ' via ${method.label}'}'
              ' on **#${order.id} · ${order.eventName}**',
        ) !=
        null;
  }

  /// Records the COLLATERAL deposit as received (refunded at return).
  bool markCollateralReceived(RentalOrder order, {PaymentMethod? method}) {
    if (order.collateralAmount <= 0 || order.collateralPaidAt != null) {
      return false;
    }
    return _applyOrderPatch(
          order,
          (o) => o.copyWith(
              collateralPaidAt: DateTime.now(), collateralMethod: method),
          type: ActivityType.payment,
          body: '**${_account?.name ?? 'Someone'}** held a **collateral deposit '
              '${Fmt.moneySmart(order.collateralAmount)}**'
              '${method == null ? '' : ' via ${method.label}'}'
              ' on **#${order.id} · ${order.eventName}**',
        ) !=
        null;
  }

  /// Records that the customer\'s ID was sighted and matches the
  /// directory record ([Customer.idType]/[idNumber] when known).
  bool markIdVerified(RentalOrder order) {
    if (order.idVerifiedAt != null) return false;
    return _applyOrderPatch(
          order,
          (o) => o.copyWith(idVerifiedAt: DateTime.now()),
          type: ActivityType.orderUpdate,
          body: '**${_account?.name ?? 'Someone'}** verified the customer ID '
              'for **#${order.id} · ${order.eventName}**',
        ) !=
        null;
  }

  /// Stores the signed rental agreement (strokes + printed name) on the
  /// order. The strokes must already be normalized to the signature
  /// grid (see [signatureToDoc] for the codec).
  bool saveSignature(RentalOrder order,
      {required List<List<Offset>> strokes, required String signedName}) {
    final data = signatureToDoc(strokes);
    if (data.isEmpty || data.length > 2800) {
      _emit('Signature could not be stored — please sign again.',
          error: true);
      notifyListeners();
      return false;
    }
    final name = signedName.trim().isEmpty
        ? (customerByName(order.customerName)?.name ?? order.customerName)
        : signedName.trim();
    return _applyOrderPatch(
          order,
          (o) => o.copyWith(
                signatureData: data,
                signedName: name,
                signedAt: DateTime.now(),
              ),
          type: ActivityType.orderUpdate,
          body: '**${_account?.name ?? 'Someone'}** captured the signed rental '
              'agreement for **#${order.id} · ${order.eventName}** (signed by $name)',
        ) !=
        null;
  }

  /// Money outstanding across every open order — down payments,
  /// remaining balances and collateral not yet received.
  double get outstandingMoneyTotal => _orders
      .where((o) => o.status.isOpen)
      .fold(0, (s, o) => s + o.outstandingTotal);

  /// Orders open for at least one handover requirement — the pick-up
  /// shortlist the front desk works from.
  List<RentalOrder> get awaitingHandoverOrders => _orders
      .where((o) => o.status.isOpen && !o.canHandOver)
      .toList();

  // -------------------------------------------------------------- customers
  late List<Customer> _customers;
  String _customerQuery = '';

  List<Customer> get customers => List.unmodifiable(_customers);
  String get customerQuery => _customerQuery;

  List<Customer> get filteredCustomers {
    if (_customerQuery.trim().isEmpty) return _customers;
    final q = _customerQuery.trim().toLowerCase();
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.company.toLowerCase().contains(q))
        .toList();
  }

  void setCustomerQuery(String q) {
    _customerQuery = q;
    notifyListeners();
  }

  /// Adds a customer to the directory (both roles — the front desk
  /// signs customers up as they walk in).
  void addCustomer({
    required String name,
    required String company,
    required String email,
    required String phone,
    String idType = '',
    String idNumber = '',
  }) {
    if (!role.canManageCustomers) {
      _deny('manage customers');
      notifyListeners();
      return;
    }
    final customer = Customer(
      id: _nextId('CUS', _customers.map((c) => c.id)),
      name: name,
      company: company,
      email: email,
      phone: phone,
      idType: idType,
      idNumber: idNumber,
      rentals: 0,
      lifetimeSpend: 0,
      lastBooking: DateTime.now(),
      avatarColor:
          kAvatarPalette[_customers.length % kAvatarPalette.length],
    );
    _customers = [customer, ..._customers];
    final b = _backend;
    if (b != null) {
      _push(b.putCustomer(customer, isNew: true), 'customers.put');
    }
    _log(
      type: ActivityType.note,
      body: '**${_account?.name ?? 'Someone'}** added customer **$name**',
    );
    notifyListeners();
  }

  // --------------------------------------------------------------- activity
  late List<ActivityEntry> _activity;
  int _unreadActivity = 0;
  String _activityFilter = 'All';

  List<ActivityEntry> get activity => List.unmodifiable(_activity);
  int get unreadActivity => _unreadActivity;
  String get activityFilter => _activityFilter;

  /// Activity entries logged by the signed-in user (employee's "my day").
  List<ActivityEntry> get myActivity {
    final name = _account?.name;
    if (name == null) return const [];
    return _activity.where((a) => a.actor == name).toList();
  }

  List<ActivityEntry> get filteredActivity {
    if (_activityFilter == 'All') return _activity;
    return _activity
        .where((a) => a.type.label == _activityFilter)
        .toList();
  }

  /// True when [t] falls on the same calendar day as "now".
  static bool _isToday(DateTime t) {
    final n = DateTime.now();
    return t.year == n.year && t.month == n.month && t.day == n.day;
  }

  /// Entries logged today (honest "today" numbers for the activity hero).
  List<ActivityEntry> get todaysActivity =>
      _activity.where((a) => _isToday(a.at)).toList();

  int get actionsTodayCount => todaysActivity.length;
  int get activityTotalCount => _activity.length;
  int get paymentsTodayCount => _activity
      .where((a) => a.type == ActivityType.payment && _isToday(a.at))
      .length;
  int get rentalUpdatesCount => _activity
      .where((a) =>
          (a.type == ActivityType.orderUpdate ||
              a.type == ActivityType.rental) &&
          _isToday(a.at))
      .length;

  void setActivityFilter(String f) {
    _activityFilter = f;
    notifyListeners();
  }

  /// Sequential, human-readable document ids: RW-2052, INV-007, CUS-006.
  /// The front desk reads these out loud, so they count up from the
  /// highest existing number instead of leaking a microsecond timestamp
  /// ("RW-HND3ZUDMG"). Still unique against everything loaded — the
  /// workspace loads full collections, and the bump loop absorbs a
  /// simultaneous second client.
  String _nextId(String prefix, Iterable<String> existingIds) {
    var max = 0;
    var width = 3;
    final re = RegExp('^$prefix-${r'(\d+)$'}');
    for (final id in existingIds) {
      final m = re.firstMatch(id);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      if (n > max) max = n;
      if (m.group(1)!.length > width) width = m.group(1)!.length;
    }
    final taken = existingIds.toSet();
    var next = max + 1;
    while (taken.contains('$prefix-${next.toString().padLeft(width, '0')}')) {
      next++;
    }
    return '$prefix-${next.toString().padLeft(width, '0')}';
  }

  void _log({required ActivityType type, required String body}) {
    final account = _account;
    final entry = ActivityEntry(
      id: _nextId('ACT', _activity.map((a) => a.id)),
      actor: account?.name ?? 'Someone',
      actorInitials: account?.initials ?? '??',
      actorColor: account?.role == UserRole.owner
          ? AppColors.avatarIndigo
          : AppColors.avatarGreen,
      at: DateTime.now(),
      type: type,
      body: body,
    );
    _activity = [entry, ..._activity];
    final b = _backend;
    if (b != null) {
      _push(b.putActivity(entry), 'activities.put');
    }
  }

  // ---------------------------------------------------------------- pickups
  late List<Pickup> _pickups;
  List<Pickup> get pickups => List.unmodifiable(_pickups);

  // --------------------------------------------------------------- bookings
  /// Creates a booking (both roles — core front-desk operation):
  /// decrements availability, appends an order, writes activity and
  /// updates the customer's stats. Returns the generated order id.
  ///
  /// The payment plan is agreed HERE: [downPayment] (collected first —
  /// tap "Mark received" on the order once the money lands) and
  /// [collateralAmount] (held until the items come back). Both, plus
  /// the remaining balance, ID check and signature, must be done
  /// before the items may leave the shop.
  String createBooking({
    required String customerName,
    required String eventName,
    required DateTime eventDate,
    required List<BookingLine> lines,
    String? notes,
    double downPayment = 0,
    double collateralAmount = 0,
  }) {
    if (!role.canOperateRentals) {
      _deny('create bookings');
      notifyListeners();
      return '';
    }
    final id = _nextId('RW', _orders.map((o) => o.id));
    final total = lines.fold<double>(
        0, (sum, l) => sum + l.qty * l.item.ratePerDay);
    final itemCount = lines.fold<int>(0, (sum, l) => sum + l.qty);

    // decrement availability
    final affected = <InventoryItem>[];
    for (final line in lines) {
      final idx = _inventory.indexWhere((i) => i.id == line.item.id);
      if (idx == -1) continue;
      final item = _inventory[idx];
      final updated = item.copyWith(
        available: (item.available - line.qty).clamp(0, item.totalStock),
      );
      _inventory[idx] = updated;
      affected.add(updated);
    }

    final order = RentalOrder(
      id: id,
      eventName: eventName,
      customerName: customerName,
      contactName: customerName,
      createdAt: DateTime.now(),
      eventDate: eventDate,
      itemCount: itemCount,
      total: total,
      status: OrderStatus.confirmed,
      notes: (notes == null || notes.trim().isEmpty) ? '' : notes.trim(),
      downPayment: downPayment.clamp(0, double.infinity),
      collateralAmount: collateralAmount.clamp(0, double.infinity),
      lineItems: lines
          .map((l) => OrderLine(
                itemName: l.item.name,
                qty: l.qty,
                unitPrice: l.item.ratePerDay,
              ))
          .toList(growable: false),
    );
    _orders = [order, ..._orders];

    final summary = lines.map((l) => '${l.item.name} ×${l.qty}').join(', ');
    _log(
      type: ActivityType.newBooking,
      body: '**${_account?.name ?? 'Someone'}** created a rental for **${Fmt.items(itemCount)} · $eventName** ($summary)',
    );

    // attach booking to a matching customer if present
    Customer? updatedCustomer;
    final cIdx =
        _customers.indexWhere((c) => c.name.toLowerCase() == customerName.toLowerCase());
    if (cIdx != -1) {
      updatedCustomer = _customers[cIdx].copyWith(
        rentals: _customers[cIdx].rentals + 1,
        lifetimeSpend: _customers[cIdx].lifetimeSpend + total,
        lastBooking: DateTime.now(),
      );
      _customers[cIdx] = updatedCustomer;
    }

    final b = _backend;
    if (b != null) {
      _push(b.putOrder(order, isNew: true), 'orders.booking');
      for (final item in affected) {
        _push(b.putInventoryItem(item, isNew: false), 'inventory.booking');
      }
      if (updatedCustomer != null) {
        _push(b.putCustomer(updatedCustomer, isNew: false),
            'customers.booking');
      }
    }

    notifyListeners();
    return id;
  }

  // --------------------------------------------------------------- metrics
  // Zeroed until a successful Appwrite sign-in replaces them with the
  // live metrics document. Nothing is pre-seeded.
  double _grossMonthK = 0;
  double _utilizationPct = 0;
  late List<RevenuePoint> _earnings;
  late List<RevenuePoint> _trend;
  List<CategoryRevenue> _categoryRevenue = const [];

  double get monthGrossRevenueK => _grossMonthK;
  double get utilization => _utilizationPct;
  List<RevenuePoint> get earnings => _earnings;
  List<RevenuePoint> get revenueTrend => _trend;
  List<CategoryRevenue> get categorySeries => _categoryRevenue;
}
