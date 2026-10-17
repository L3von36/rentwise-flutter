import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/palette.dart';
import '../data/seed_data.dart';
import '../models/account.dart';
import '../models/activity_entry.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/pickup.dart';
import '../models/rental_order.dart';
import '../models/shift_task.dart';
import '../services/appwrite_backend.dart';

/// Workspace sections (sidebar / drawer destinations).
enum Section { dashboard, inventory, orders, customers, activity, access, reports }

extension SectionX on Section {
  String get label => switch (this) {
        Section.dashboard => 'Dashboard',
        Section.inventory => 'Inventory',
        Section.orders => 'Orders',
        Section.customers => 'Customers',
        Section.activity => 'Activity Log',
        Section.access => 'Access & roles',
        Section.reports => 'Reports',
      };

  String get breadcrumb => switch (this) {
        Section.dashboard => 'Operations overview',
        Section.inventory => 'Inventory',
        Section.orders => 'Orders',
        Section.customers => 'Customers',
        Section.activity => 'Activity Log',
        Section.access => 'Access & roles',
        Section.reports => 'Reports',
      };
}

/// Booking line inside the new-rental-booking sheet.
class BookingLine {
  final InventoryItem item;
  int qty;
  BookingLine({required this.item, this.qty = 1});
}

/// Single source of truth for the whole workspace.
///
/// One store keeps cross-screen reactions trivial:
/// creating a booking decrements availability, appends an order,
/// writes an activity entry and bumps the sidebar badge.
///
/// When an [AppwriteBackend] is injected, every mutation is written
/// through to Appwrite Cloud and sign-in loads the live workspace.
/// Without one (widget tests / offline demo mode) the store runs on the
/// local seed dataset exactly as before.
class WorkspaceState extends ChangeNotifier {
  WorkspaceState({AppwriteBackend? backend}) : _backend = backend {
    final now = DateTime.now();
    _inventory = Seed.inventory();
    _orders = Seed.orders(now);
    _customers = Seed.customers(now);
    _activity = Seed.activity(now);
    _pickups = Seed.pickups(now);
  }

  final AppwriteBackend? _backend;

  /// Fire-and-forget persistence — the local store stays the UI truth;
  /// Appwrite failures are logged and never block the interaction.
  void _push(Future<void> work, String label) {
    work.catchError((Object e) {
      debugPrint('Appwrite[$label] $e');
    });
  }

  // -------------------------------------------------------------- workspace
  final List<String> _workspaces = [Seed.workspaceName];
  String _workspace = Seed.workspaceName;

  List<String> get workspaces => List.unmodifiable(_workspaces);
  String get workspace => _workspace;

  /// True when this workspace is the one being viewed.
  bool get isSingleWorkspace => _workspaces.length == 1;

  void switchWorkspace(String name) {
    if (!_workspaces.contains(name) || name == _workspace) return;
    _workspace = name;
    _backend?.setActiveWorkspace(name);
    _log(
      type: ActivityType.note,
      body: '**${_account?.name ?? 'Someone'}** switched to workspace **$name**',
    );
    notifyListeners();
  }

  /// Creates and switches to a new workspace. Returns false when the
  /// name is empty or already taken.
  bool addWorkspace(String name) {
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

  Future<void> signIn(UserRole role) async {
    _loadingAuth = true;
    _authError = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _account = role == UserRole.owner
        ? Seed.demoOwner.copyWith(role: UserRole.owner)
        : Seed.demoEmployee.copyWith(role: UserRole.employee);
    _loadingAuth = false;
    _section = Section.dashboard;
    notifyListeners();
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
        // No backend configured (tests / offline fallback): map the email
        // to the closest demo persona so the flow still completes.
        await signIn(
            email.trim().toLowerCase().startsWith('selam')
                ? UserRole.owner
                : UserRole.employee);
        return null;
      }
      _account = await b.authenticate(email, password);
      final snap = await b.loadWorkspace();
      if (snap.inventory.isNotEmpty) _inventory = snap.inventory;
      if (snap.orders.isNotEmpty) _orders = snap.orders;
      if (snap.customers.isNotEmpty) _customers = snap.customers;
      if (snap.activity.isNotEmpty) _activity = snap.activity;
      if (snap.pickups.isNotEmpty) _pickups = snap.pickups;
      if (snap.workspaces.isNotEmpty) {
        _workspaces
          ..clear()
          ..addAll(snap.workspaces);
        if (!_workspaces.contains(Seed.workspaceName)) {
          _workspaces.add(Seed.workspaceName);
        }
      }
      if (snap.activeWorkspace.isNotEmpty &&
          _workspaces.contains(snap.activeWorkspace)) {
        _workspace = snap.activeWorkspace;
      }
      if (snap.earnings.isNotEmpty) _earnings = snap.earnings;
      if (snap.trend.isNotEmpty) _trend = snap.trend;
      if (snap.categoryRevenue.isNotEmpty) {
        _categoryRevenue = snap.categoryRevenue;
      }
      _grossMonthK = snap.grossMonthK;
      _utilizationPct = snap.utilizationPct;
      _loadingAuth = false;
      _section = Section.dashboard;
      notifyListeners();
      return null;
    } catch (e) {
      _loadingAuth = false;
      _authError = AppwriteBackend.authErrorText(e);
      notifyListeners();
      return _authError;
    }
  }

  /// Switch role in place (used by the owner-only Access & roles screen).
  /// Swaps the demo persona to match the design captures
  /// (Jordan Miller for Employee, Olivia Wells for Owner).
  ///
  /// Owners may switch to the employee role to preview their view;
  /// employees can never promote themselves — only owners manage access.
  void switchRole(UserRole role) {
    if (!isOwner) return;
    if (_account == null || _account!.role == role) return;
    _account = role == UserRole.owner ? Seed.demoOwner : Seed.demoEmployee;
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
    notifyListeners();
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
            meta: '#${o.id} · ${o.eventName} · ${o.itemCount} items',
            chip: 'Prep',
            chipFg: AppPalette.amber,
            chipBg: AppPalette.amberBg,
            kind: 'prep',
            orderId: o.id,
          ));
        case OrderStatus.outForDelivery:
          tasks.add(ShiftTask(
            title: 'Confirm delivery',
            meta: '#${o.id} · ${o.eventName} · ${o.contactName}',
            chip: 'On the road',
            chipFg: AppPalette.blue,
            chipBg: AppPalette.blueBg,
            kind: 'delivery',
            orderId: o.id,
          ));
        case OrderStatus.needsPayment:
          tasks.add(ShiftTask(
            title: 'Collect payment',
            meta: '#${o.id} · ${o.eventName} · \$${o.total.toStringAsFixed(0)}',
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
            '${p.itemCount} items · ${p.venue} · #${p.id}',
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
  String _categoryFilter = Seed.categories.first;
  String _inventoryQuery = '';

  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  String get categoryFilter => _categoryFilter;
  String get inventoryQuery => _inventoryQuery;

  List<InventoryItem> get filteredInventory {
    Iterable<InventoryItem> items = _inventory;
    if (_categoryFilter != Seed.categories.first) {
      items = items.where((i) => i.category == _categoryFilter);
    }
    if (_inventoryQuery.trim().isNotEmpty) {
      final q = _inventoryQuery.trim().toLowerCase();
      items = items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q));
    }
    return items.toList();
  }

  void setCategoryFilter(String c) {
    _categoryFilter = c;
    notifyListeners();
  }

  void setInventoryQuery(String q) {
    _inventoryQuery = q;
    notifyListeners();
  }

  int get totalUnits =>
      _inventory.fold(0, (sum, i) => sum + i.totalStock);
  int get availableUnits =>
      _inventory.fold(0, (sum, i) => sum + i.available);
  int get onRentUnits =>
      _inventory.fold(0, (sum, i) => sum + (i.totalStock - i.available));
  int get attentionItems =>
      _inventory.where((i) => i.needsAttention).length;

  void addInventoryItem({
    required String name,
    required String category,
    required int totalStock,
    required double ratePerDay,
  }) {
    final item = InventoryItem(
      id: 'INV-${(_inventory.length + 1).toString().padLeft(3, '0')}',
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

  void adjustStock(InventoryItem item, {int? totalStock, int? available}) {
    final idx = _inventory.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    final updated = item.copyWith(
        totalStock: totalStock, available: available);
    _inventory[idx] = updated;
    final b = _backend;
    if (b != null) {
      _push(b.putInventoryItem(updated, isNew: false), 'inventory.adjust');
    }
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
  double get awaitingPaymentTotal => _orders
      .where((o) => o.status == OrderStatus.needsPayment)
      .fold(0, (s, o) => s + o.total);
  int get outForDeliveryCount =>
      _orders.where((o) => o.status == OrderStatus.outForDelivery).length;
  int get returnsTodayCount =>
      _orders.where((o) => o.status == OrderStatus.outForDelivery).length;

  void setOrderTab(String tab) {
    _orderTab = tab;
    notifyListeners();
  }

  /// Tapping the active chip again clears the filter ([status] == null).
  void setOrderStatusFilter(OrderStatus? status) {
    _orderStatusFilter = status;
    notifyListeners();
  }

  void updateOrderStatus(RentalOrder order, OrderStatus status) {
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx == -1) return;
    final updated = order.copyWith(status: status);
    _orders[idx] = updated;
    final b = _backend;
    if (b != null) {
      _push(b.putOrder(updated, isNew: false), 'orders.status');
    }
    _log(
      type: ActivityType.orderUpdate,
      body: '**${_account?.name ?? 'Someone'}** updated order **#${order.id} · ${order.eventName}**',
    );
    notifyListeners();
  }

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

  void addCustomer({
    required String name,
    required String company,
    required String email,
    required String phone,
  }) {
    final customer = Customer(
      id: 'CUS-${(_customers.length + 1).toString().padLeft(3, '0')}',
      name: name,
      company: company,
      email: email,
      phone: phone,
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
  int _unreadActivity = 4;
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

  int get actionsTodayCount => _activity.length;
  int get paymentsTodayCount => _activity
      .where((a) => a.type == ActivityType.payment)
      .length;
  int get rentalUpdatesCount => _activity
      .where((a) =>
          a.type == ActivityType.orderUpdate ||
          a.type == ActivityType.rental)
      .length;

  void setActivityFilter(String f) {
    _activityFilter = f;
    notifyListeners();
  }

  void _log({required ActivityType type, required String body}) {
    final account = _account;
    final entry = ActivityEntry(
      id: 'ACT-${1000 + _activity.length + 1}',
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
  /// Creates a booking: decrements availability, appends an order,
  /// writes activity. Returns the generated order id.
  String createBooking({
    required String customerName,
    required String eventName,
    required DateTime eventDate,
    required List<BookingLine> lines,
    String? notes,
  }) {
    final id = 'RW-${2052 + _orders.length - 5}';
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
      lineItems: lines
          .map((l) => OrderLine(
                itemName: l.item.name,
                qty: l.qty,
                unitPrice: l.item.ratePerDay,
              ))
          .toList(growable: false),
    );
    _orders = [order, ..._orders];

    final summary = lines
        .map((l) => '${l.qty} ${l.item.name.toLowerCase()}')
        .join(', ');
    _log(
      type: ActivityType.newBooking,
      body: '**${_account?.name ?? 'Someone'}** created a rental for **$itemCount items · $eventName** ($summary)',
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

  /// Aggregate helpers for the Reports screen — numbers loaded from the
  /// Appwrite metrics document once signed in, seed values before that.
  late double _grossMonthK = Seed.grossRevenueMonth;
  late double _utilizationPct = Seed.utilizationPct;
  List<RevenuePoint> _earnings = const [];
  List<RevenuePoint> _trend = const [];
  List<CategoryRevenue> _categoryRevenue = Seed.categoryRevenue;

  double get monthGrossRevenueK => _grossMonthK;
  double get utilization => _utilizationPct;
  List<RevenuePoint> earningsSeries(DateTime now) =>
      _earnings.isEmpty ? Seed.earningsDaily(now) : _earnings;
  List<RevenuePoint> trendSeries(DateTime now) =>
      _trend.isEmpty ? Seed.revenueTrend(now) : _trend;
  List<CategoryRevenue> get categorySeries => _categoryRevenue;
}
