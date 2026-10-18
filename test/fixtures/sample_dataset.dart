import 'package:flutter/material.dart';
import 'package:rentwise/models/account.dart';
import 'package:rentwise/models/activity_entry.dart';
import 'package:rentwise/models/customer.dart';
import 'package:rentwise/models/inventory_item.dart';
import 'package:rentwise/models/pickup.dart';
import 'package:rentwise/models/rental_order.dart';
import 'package:rentwise/core/app_colors.dart';

/// Test-only sample dataset (the "Riverside Events" workspace) matching
/// the RentWise design pack. Lives under test/ — the shipped app bundles
/// no data whatsoever; this fixture feeds the cloud-provisioning harness
/// and the in-memory fake backend used by UI tests.
class SampleDataset {
  SampleDataset._();

  static const String workspaceName = 'Riverside Events';

  static Account demoEmployee = const Account(
    name: 'Jordan Miller',
    email: 'jordan@riverside.events',
    role: UserRole.employee,
    initials: 'JM',
    title: 'Operations associate',
  );

  static Account demoOwner = const Account(
    name: 'Olivia Wells',
    email: 'olivia@riverside.events',
    role: UserRole.owner,
    initials: 'OW',
    title: 'Workspace owner',
  );

  // ---------------------------------------------------------------- inventory
  static List<InventoryItem> inventory() => [
        const InventoryItem(
          id: 'INV-001',
          name: 'Folding Chairs',
          note: 'Last checked today',
          category: 'Seating',
          totalStock: 240,
          available: 190,
          ratePerDay: 1.50,
          icon: Icons.event_seat,
        ),
        const InventoryItem(
          id: 'INV-002',
          name: '6ft Round Tables',
          note: '36 out on events',
          category: 'Tables',
          totalStock: 48,
          available: 12,
          ratePerDay: 6.00,
          icon: Icons.table_bar,
        ),
        const InventoryItem(
          id: 'INV-003',
          name: 'String Lights',
          note: 'Ready to dispatch',
          category: 'Lighting',
          totalStock: 64,
          available: 64,
          ratePerDay: 12.00,
          icon: Icons.lightbulb_outline,
        ),
        const InventoryItem(
          id: 'INV-004',
          name: 'White Linen 90"',
          note: 'Cleaning in progress',
          category: 'Linens',
          totalStock: 120,
          available: 0,
          maintenance: true,
          ratePerDay: 2.25,
          icon: Icons.dry_cleaning_outlined,
        ),
        const InventoryItem(
          id: 'INV-005',
          name: 'Oak Bar Set',
          note: '3 sets available',
          category: 'Furniture',
          totalStock: 8,
          available: 3,
          ratePerDay: 45.00,
          icon: Icons.local_bar_outlined,
        ),
        const InventoryItem(
          id: 'INV-006',
          name: 'Bistro Heaters',
          note: '10 on active orders',
          category: 'Outdoor',
          totalStock: 16,
          available: 6,
          ratePerDay: 8.00,
          icon: Icons.heat_pump_outlined,
        ),
      ];

  static const List<String> categories = [
    'All categories',
    'Seating',
    'Tables',
    'Lighting',
    'Linens',
    'Furniture',
    'Outdoor',
  ];

  // ------------------------------------------------------------------- orders
  static List<RentalOrder> orders(DateTime now) => [
        RentalOrder(
          id: 'RW-2051',
          eventName: 'Northstar Product Launch',
          customerName: 'Mia Chen',
          contactName: 'Mia Chen',
          createdAt: now.subtract(const Duration(days: 2)),
          eventDate: now.add(const Duration(days: 5)),
          itemCount: 18,
          total: 1840,
          status: OrderStatus.preparing,
          notes:
              'Deliver to loading dock B before 2 PM. Stage crates are labeled NORTHSTAR. Venue contact: Mia Chen.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 10, unitPrice: 40),
            OrderLine(itemName: '6ft Round Tables', qty: 4, unitPrice: 90),
            OrderLine(itemName: 'String Lights', qty: 2, unitPrice: 180),
            OrderLine(itemName: 'Oak Bar Set', qty: 2, unitPrice: 360),
          ],
        ),
        RentalOrder(
          id: 'RW-2048',
          eventName: 'The Harper Wedding',
          customerName: 'Avery Harper',
          contactName: 'Avery Harper',
          createdAt: now.subtract(const Duration(days: 2)),
          eventDate: now.add(const Duration(days: 4)),
          itemCount: 42,
          total: 3240,
          status: OrderStatus.confirmed,
          notes:
              'Ceremony setup complete by 10 AM — linens pressed white-on-white. Oak bar set backs the cake table.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 20, unitPrice: 40),
            OrderLine(itemName: '6ft Round Tables', qty: 8, unitPrice: 90),
            OrderLine(itemName: 'String Lights', qty: 6, unitPrice: 120),
            OrderLine(itemName: 'White Linen 90"', qty: 6, unitPrice: 90),
            OrderLine(itemName: 'Oak Bar Set', qty: 2, unitPrice: 230),
          ],
        ),
        RentalOrder(
          id: 'RW-2046',
          eventName: 'Monroe Family Reunion',
          customerName: 'Tara Monroe',
          contactName: 'Tara Monroe',
          createdAt: now.subtract(const Duration(days: 3)),
          eventDate: now.add(const Duration(days: 7)),
          itemCount: 64,
          total: 2110,
          status: OrderStatus.needsPayment,
          notes:
              'Balance due on delivery. Park pavilion has limited power — pack spare extension cords and the heaters.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 36, unitPrice: 25),
            OrderLine(itemName: '6ft Round Tables', qty: 10, unitPrice: 55),
            OrderLine(itemName: 'White Linen 90"', qty: 14, unitPrice: 30),
            OrderLine(itemName: 'Bistro Heaters', qty: 4, unitPrice: 60),
          ],
        ),
        RentalOrder(
          id: 'RW-2042',
          eventName: 'Marlow Studio Dinner',
          customerName: 'Eli Marlow',
          contactName: 'Eli Marlow',
          createdAt: now.subtract(const Duration(days: 5)),
          eventDate: now.add(const Duration(days: 2)),
          itemCount: 12,
          total: 720,
          status: OrderStatus.outForDelivery,
          notes:
              'Narrow stairwell at the studio — carry tables flat. Call Eli on arrival for parking access.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 6, unitPrice: 30),
            OrderLine(itemName: '6ft Round Tables', qty: 3, unitPrice: 80),
            OrderLine(itemName: 'String Lights', qty: 2, unitPrice: 75),
            OrderLine(itemName: 'Oak Bar Set', qty: 1, unitPrice: 150),
          ],
        ),
        RentalOrder(
          id: 'RW-2039',
          eventName: 'Brighton Arts Gala',
          customerName: 'Lena Ortiz',
          contactName: 'Lena Ortiz',
          createdAt: now.subtract(const Duration(days: 8)),
          eventDate: now.subtract(const Duration(days: 2)),
          itemCount: 31,
          total: 2680,
          status: OrderStatus.returned,
          notes:
              'Teardown happened the same night. Confirm glassware count against the manifest before restocking.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 14, unitPrice: 35),
            OrderLine(itemName: '6ft Round Tables', qty: 6, unitPrice: 100),
            OrderLine(itemName: 'String Lights', qty: 5, unitPrice: 150),
            OrderLine(itemName: 'White Linen 90"', qty: 4, unitPrice: 75),
            OrderLine(itemName: 'Oak Bar Set', qty: 2, unitPrice: 270),
          ],
        ),
      ];

  // ---------------------------------------------------------------- customers
  static List<Customer> customers(DateTime now) => [
        Customer(
          id: 'CUS-001',
          name: 'Avery Harper',
          company: 'The Harper Wedding',
          email: 'avery@harperwed.com',
          phone: '(555) 201-4477',
          rentals: 8,
          lifetimeSpend: 8420,
          lastBooking: now.subtract(const Duration(days: 5)),
          avatarColor: AppColors.avatarGreen,
        ),
        Customer(
          id: 'CUS-002',
          name: 'Mia Chen',
          company: 'Northstar Events',
          email: 'mia@northstar.events',
          phone: '(555) 883-2014',
          rentals: 5,
          lifetimeSpend: 5180,
          lastBooking: now.subtract(const Duration(days: 16)),
          avatarColor: AppColors.avatarTeal,
        ),
        Customer(
          id: 'CUS-003',
          name: 'Tara Monroe',
          company: 'Monroe Family',
          email: 'tara.monroe@gmail.com',
          phone: '(555) 340-9982',
          rentals: 4,
          lifetimeSpend: 4920,
          lastBooking: now.subtract(const Duration(days: 28)),
          avatarColor: AppColors.avatarOrange,
        ),
        Customer(
          id: 'CUS-004',
          name: 'Eli Marlow',
          company: 'Marlow Studio',
          email: 'eli@marlow.studio',
          phone: '(555) 771-6620',
          rentals: 3,
          lifetimeSpend: 2280,
          lastBooking: now.subtract(const Duration(days: 45)),
          avatarColor: AppColors.avatarPurple,
        ),
        Customer(
          id: 'CUS-005',
          name: 'Lena Ortiz',
          company: 'Brighton Arts',
          email: 'lena@brightonarts.org',
          phone: '(555) 418-2231',
          rentals: 3,
          lifetimeSpend: 6110,
          lastBooking: now.subtract(const Duration(days: 2)),
          avatarColor: AppColors.avatarBlue,
        ),
      ];

  // ----------------------------------------------------------------- activity
  static List<ActivityEntry> activity(DateTime now) {
    final jm = SampleDataset.demoEmployee;
    Color jmColor = AppColors.avatarGreen;
    return [
      ActivityEntry(
        id: 'ACT-1001',
        actor: jm.name,
        actorInitials: jm.initials,
        actorColor: jmColor,
        at: DateTime(now.year, now.month, now.day, 10, 45),
        type: ActivityType.rental,
        body: '**${jm.name}** rented out **50 folding chairs**',
      ),
      ActivityEntry(
        id: 'ACT-1002',
        actor: jm.name,
        actorInitials: jm.initials,
        actorColor: AppColors.avatarPurple,
        at: DateTime(now.year, now.month, now.day, 11, 15),
        type: ActivityType.payment,
        body: '**${jm.name}** recorded cash payment of **\$200.00**',
      ),
      ActivityEntry(
        id: 'ACT-1003',
        actor: jm.name,
        actorInitials: jm.initials,
        actorColor: AppColors.avatarPurple,
        at: DateTime(now.year, now.month, now.day, 11, 32),
        type: ActivityType.orderUpdate,
        body: '**${jm.name}** updated order **#RW-2048 · The Harper Wedding**',
      ),
      ActivityEntry(
        id: 'ACT-1004',
        actor: jm.name,
        actorInitials: jm.initials,
        actorColor: AppColors.avatarOrange,
        at: DateTime(now.year, now.month, now.day, 12, 6),
        type: ActivityType.returnItem,
        body: '**${jm.name}** marked returned **12 Bistro Heaters**',
      ),
      ActivityEntry(
        id: 'ACT-1005',
        actor: jm.name,
        actorInitials: jm.initials,
        actorColor: AppColors.avatarIndigo,
        at: DateTime(now.year, now.month, now.day, 12, 21),
        type: ActivityType.note,
        body: '**${jm.name}** added a note to **#RW-2051 · Northstar**',
      ),
      ActivityEntry(
        id: 'ACT-1006',
        actor: jm.name,
        actorInitials: jm.initials,
        actorColor: AppColors.avatarGreen,
        at: DateTime(now.year, now.month, now.day, 12, 44),
        type: ActivityType.newBooking,
        body: '**${jm.name}** created a rental for **24 Oak Bar Sets**',
      ),
    ];
  }

  // ------------------------------------------------------------------ pickups
  static List<Pickup> pickups(DateTime now) => [
        Pickup(
          id: 'P-01',
          date: now.add(const Duration(days: 4)),
          title: 'Harper + Co. wedding',
          venue: 'Oakwood Estate',
          itemCount: 42,
          contactName: 'Avery Harper',
        ),
        Pickup(
          id: 'P-02',
          date: now.add(const Duration(days: 5)),
          title: 'Northstar product launch',
          venue: 'Foundry Hall',
          itemCount: 18,
          contactName: 'Mia Chen',
        ),
        Pickup(
          id: 'P-03',
          date: now.add(const Duration(days: 7)),
          title: 'Monroe family reunion',
          venue: 'Riverside Park',
          itemCount: 64,
          contactName: 'Tara Monroe',
        ),
      ];

  // ------------------------------------------------------------------ reports
  static List<RevenuePoint> revenueTrend(DateTime now) {
    final values = [1.9, 2.6, 2.2, 3.1, 2.8, 3.4, 4.1];
    return List.generate(
      values.length,
      (i) => RevenuePoint(
        day: now.subtract(Duration(days: (values.length - 1 - i) * 2)),
        value: values[i],
      ),
    );
  }

  /// Daily gross bookings for the owner earnings chart (last 12 days,
  /// in $k). Sums to the month-to-date figure (28.9k).
  static List<RevenuePoint> earningsDaily(DateTime now) {
    final values = [
      1.9, 2.3, 2.1, 2.6, 2.2, 2.8, 2.4, 2.9, 2.0, 2.6, 2.4, 2.7,
    ];
    return List.generate(
      values.length,
      (i) => RevenuePoint(
        day: now.subtract(Duration(days: values.length - 1 - i)),
        value: values[i],
      ),
    );
  }

  static const List<CategoryRevenue> categoryRevenue = [
    CategoryRevenue(category: 'Seating', amount: 8420),
    CategoryRevenue(category: 'Tables', amount: 5120),
    CategoryRevenue(category: 'Lighting', amount: 3860),
    CategoryRevenue(category: 'Linens', amount: 2940),
  ];

  // ---------------------------------------------------------------- dashboard
  static const double todaysRevenue = 2480;
  static const double yesterdaysRevenue = 2200;
  static const double revenueTrendPct = 12.8;
  static const int activeRentals = 24;
  static const double activeTrendPct = 4.2;
  static const int pendingReturns = 8;
  static const int returnsDueToday = 2;
  static const String nextDispatchTime = '3:30 PM';
  static const String nextDispatchVenue = 'Oakwood Estate';
  static const int nextDispatchItems = 12;

  static const int totalCustomersKpi = 184;
  static const int newCustomersDelta = 12;
  static const double repeatCustomerPct = 68;
  static const double repeatTrendPct = 8.4;
  static const double customerValueK = 42.8;
  static const double valueTrendPct = 14.2;
  static const int followUps = 7;

  static const double leadTimeGainPct = 18;
  static const double grossRevenueMonth = 28.9; // $k
  static const double grossRevenueTrend = 18.4;
  static const double utilizationPct = 72.8;
  static const double utilizationTrend = 6.2;
  static const int workspaceOnTimePct = 98;

  static const int inventoryTotal = 496;
  static const int inventoryDelta = 24;
  static const int inventoryAvailable = 275;
  static const double availablePct = 55;
  static const int inventoryOnRent = 112;
  static const double onRentPct = 22.5;
  static const int inventoryAttention = 109;
  static const int attentionDelta = 6;

  static const int openOrders = 24;
  static const int openOrdersDelta = 4;
  static const double awaitingPayment = 4910;
  static const int awaitingPaymentOrders = 3;
  static const int outForDelivery = 6;
  static const int returnsToday = 8;
  static const int returnsLate = 2;

  static const int actionsToday = 24;
  static const int rentalUpdates = 12;
  static const int paymentsRecorded = 4;

  static const String businessCloseTime = '7:00 PM';
}
