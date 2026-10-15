import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../data/seed_data.dart';
import '../models/account.dart';
import '../models/activity_entry.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/pickup.dart';
import '../models/rental_order.dart';

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
class WorkspaceState extends ChangeNotifier {
  WorkspaceState() {
    final now = DateTime.now();
    _inventory = Seed.inventory();
    _orders = Seed.orders(now);
    _customers = Seed.customers(now);
    _activity = Seed.activity(now);
    _pickups = Seed.pickups(now);
  }

  // ------------------------------------------------------------------- auth
  Account? _account;
  bool _loadingAuth = false;

  Account? get account => _account;
  bool get isSignedIn => _account != null;
  bool get loadingAuth => _loadingAuth;
  UserRole get role => _account?.role ?? UserRole.employee;
  bool get isOwner => role == UserRole.owner;

  Future<void> signIn(UserRole role) async {
    _loadingAuth = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _account = role == UserRole.owner
        ? Seed.demoOwner.copyWith(role: UserRole.owner)
        : Seed.demoEmployee.copyWith(role: UserRole.employee);
    _loadingAuth = false;
    _section = Section.dashboard;
    notifyListeners();
  }

  /// Switch role in place (used by Access & roles screen).
  /// Swaps the demo persona to match the design captures
  /// (Jordan Miller for Employee, Olivia Wells for Owner).
  void switchRole(UserRole role) {
    if (_account == null || _account!.role == role) return;
    _account = role == UserRole.owner ? Seed.demoOwner : Seed.demoEmployee;
    if (!isOwner && _section == Section.reports) _section = Section.dashboard;
    notifyListeners();
  }

  void signOut() {
    _account = null;
    _section = Section.dashboard;
    notifyListeners();
  }

  // -------------------------------------------------------------- navigation
  Section _section = Section.dashboard;

  Section get section => _section;

  void navigate(Section s) {
    if (!isSignedIn) return;
    if (!isOwner && s == Section.reports) return;
    if (_section == s) return;
    _section = s;
    if (s == Section.activity) _unreadActivity = 0;
    notifyListeners();
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
    _log(
      type: ActivityType.newBooking,
      body: '**${_account?.name ?? 'Someone'}** added **$name** to inventory',
    );
    notifyListeners();
  }

  void adjustStock(InventoryItem item, {int? totalStock, int? available}) {
    final idx = _inventory.indexWhere((i) => i.id == item.id);
    if (idx == -1) return;
    _inventory[idx] = item.copyWith(
        totalStock: totalStock, available: available);
    notifyListeners();
  }

  // ----------------------------------------------------------------- orders
  late List<RentalOrder> _orders;
  String _orderTab = 'All orders';

  List<RentalOrder> get orders => List.unmodifiable(_orders);
  String get orderTab => _orderTab;

  List<RentalOrder> get filteredOrders {
    switch (_orderTab) {
      case 'Upcoming':
        return _orders.where((o) => o.status.isUpcoming).toList();
      case 'Completed':
        return _orders.where((o) => !o.status.isUpcoming).toList();
      default:
        return _orders;
    }
  }

  int get openOrdersCount =>
      _orders.where((o) => o.status.isOpen).length;
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

  void updateOrderStatus(RentalOrder order, OrderStatus status) {
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx == -1) return;
    _orders[idx] = order.copyWith(status: status);
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
    _activity = [
      ActivityEntry(
        id: 'ACT-${1000 + _activity.length + 1}',
        actor: account?.name ?? 'Someone',
        actorInitials: account?.initials ?? '??',
        actorColor: account?.role == UserRole.owner
            ? AppColors.avatarIndigo
            : AppColors.avatarGreen,
        at: DateTime.now(),
        type: type,
        body: body,
      ),
      ..._activity,
    ];
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
    for (final line in lines) {
      final idx = _inventory.indexWhere((i) => i.id == line.item.id);
      if (idx == -1) continue;
      final item = _inventory[idx];
      _inventory[idx] = item.copyWith(
        available: (item.available - line.qty).clamp(0, item.totalStock),
      );
    }

    _orders = [
      RentalOrder(
        id: id,
        eventName: eventName,
        customerName: customerName,
        contactName: customerName,
        createdAt: DateTime.now(),
        eventDate: eventDate,
        itemCount: itemCount,
        total: total,
        status: OrderStatus.confirmed,
      ),
      ..._orders,
    ];

    final summary = lines
        .map((l) => '${l.qty} ${l.item.name.toLowerCase()}')
        .join(', ');
    _log(
      type: ActivityType.newBooking,
      body: '**${_account?.name ?? 'Someone'}** created a rental for **$itemCount items · $eventName** ($summary)',
    );

    // attach booking to a matching customer if present
    final cIdx =
        _customers.indexWhere((c) => c.name.toLowerCase() == customerName.toLowerCase());
    if (cIdx != -1) {
      _customers[cIdx] = _customers[cIdx].copyWith(
        rentals: _customers[cIdx].rentals + 1,
        lifetimeSpend: _customers[cIdx].lifetimeSpend + total,
        lastBooking: DateTime.now(),
      );
    }

    notifyListeners();
    return id;
  }

  /// Aggregate helpers for the Reports screen.
  double get monthGrossRevenueK => Seed.grossRevenueMonth;
  double get utilization => Seed.utilizationPct;
}
