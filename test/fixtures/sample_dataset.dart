import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rentwise/models/account.dart';
import 'package:rentwise/models/activity_entry.dart';
import 'package:rentwise/models/customer.dart';
import 'package:rentwise/models/inventory_item.dart';
import 'package:rentwise/models/pickup.dart';
import 'package:rentwise/models/rental_order.dart';
import 'package:rentwise/core/app_colors.dart';
import 'package:rentwise/data/appwrite_mappers.dart';

/// Test-only sample dataset (the "Riverside Events" workspace) matching
/// the RentWise design pack. Lives under test/ — the shipped app bundles
/// no data whatsoever; this fixture feeds the cloud-provisioning harness
/// and the in-memory fake backend used by UI tests.
class SampleDataset {
  SampleDataset._();

  static const String workspaceName = 'Riverside Events';

  /// A real [signatureToDoc]-encoded cursive squiggle, so seeded orders
  /// render an actual signature thumbnail instead of a blank white box
  /// (the decoder honestly turns garbage like 'seeded-signature' into
  /// zero strokes).
  static String seededSignature() {
    List<Offset> curve(double x0, double y0, double x1, double y1,
        {double amp = 0.04, double waves = 3, int steps = 30}) {
      final pts = <Offset>[];
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = x0 + (x1 - x0) * t;
        final y = y0 + (y1 - y0) * t + amp * math.sin(t * math.pi * waves);
        pts.add(Offset(x * kSignatureGridMax, y * kSignatureGridMax));
      }
      return pts;
    }

    return signatureToDoc([
      // "M" rise, cursive middle, tail — plus an underline swoosh.
      curve(0.06, 0.64, 0.30, 0.36, amp: -0.10, waves: 4),
      curve(0.30, 0.40, 0.55, 0.56, amp: 0.10, waves: 5),
      curve(0.55, 0.56, 0.88, 0.38, amp: -0.08, waves: 3),
      curve(0.10, 0.80, 0.92, 0.70, amp: 0.03, waves: 1),
    ]);
  }

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
          ratePerDay: 20,
          icon: Icons.event_seat,
        ),
        const InventoryItem(
          id: 'INV-002',
          name: '6ft Round Tables',
          note: '36 out on events',
          category: 'Tables',
          totalStock: 48,
          available: 12,
          ratePerDay: 80,
          icon: Icons.table_bar,
        ),
        const InventoryItem(
          id: 'INV-003',
          name: 'String Lights',
          note: 'Ready to dispatch',
          category: 'Lighting',
          totalStock: 64,
          available: 64,
          ratePerDay: 100,
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
          ratePerDay: 30,
          icon: Icons.dry_cleaning_outlined,
        ),
        const InventoryItem(
          id: 'INV-005',
          name: 'Oak Bar Set',
          note: '3 sets available',
          category: 'Furniture',
          totalStock: 8,
          available: 3,
          ratePerDay: 300,
          icon: Icons.local_bar_outlined,
        ),
        const InventoryItem(
          id: 'INV-006',
          name: 'Bistro Heaters',
          note: '10 on active orders',
          category: 'Outdoor',
          totalStock: 16,
          available: 6,
          ratePerDay: 120,
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
  // Prices are Ethiopian Birr, scaled to the Addis Ababa event-rental
  // market (folding chair ~Br 50/event, round table ~Br 250, bar set
  // ~Br 950). Every total still equals the sum of its lines, and the
  // down payment is exactly half — the payment plan re-adds on screen.
  static List<RentalOrder> orders(DateTime now) => [
        RentalOrder(
          id: 'RW-2051',
          eventName: 'Northstar Product Launch',
          customerName: 'Mia Chen',
          contactName: 'Mia Chen',
          createdAt: now.subtract(const Duration(days: 2)),
          eventDate: now.add(const Duration(days: 5)),
          itemCount: 18,
          total: 4100,
          status: OrderStatus.preparing,
          notes:
              'Customer collects from the shop — stage crates are labeled NORTHSTAR. Venue contact: Mia Chen.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 10, unitPrice: 50),
            OrderLine(itemName: '6ft Round Tables', qty: 4, unitPrice: 250),
            OrderLine(itemName: 'String Lights', qty: 2, unitPrice: 350),
            OrderLine(itemName: 'Oak Bar Set', qty: 2, unitPrice: 950),
          ],
          // Fully settled in the seed — the order is staged for pickup,
          // which the payment policy only allows once everything clears.
          downPayment: 2050,
          downPaymentPaidAt: now.subtract(const Duration(days: 2)),
          downPaymentMethod: PaymentMethod.telebirr,
          remainingPaidAt: now.subtract(const Duration(days: 1)),
          remainingMethod: PaymentMethod.cbeBirr,
          collateralAmount: 500,
          collateralPaidAt: now.subtract(const Duration(days: 1)),
          collateralMethod: PaymentMethod.cash,
          idVerifiedAt: now.subtract(const Duration(days: 1)),
          signedName: 'Mia Chen',
          signatureData: seededSignature(),
          signedAt: now.subtract(const Duration(days: 1)),
        ),
        RentalOrder(
          id: 'RW-2048',
          eventName: 'The Harper Wedding',
          customerName: 'Avery Harper',
          contactName: 'Avery Harper',
          createdAt: now.subtract(const Duration(days: 2)),
          eventDate: now.add(const Duration(days: 4)),
          itemCount: 42,
          total: 7720,
          status: OrderStatus.confirmed,
          notes:
              'Ceremony setup complete by 10 AM — linens pressed white-on-white. Oak bar set backs the cake table.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 20, unitPrice: 50),
            OrderLine(itemName: '6ft Round Tables', qty: 8, unitPrice: 250),
            OrderLine(itemName: 'String Lights', qty: 6, unitPrice: 350),
            OrderLine(itemName: 'White Linen 90"', qty: 6, unitPrice: 120),
            OrderLine(itemName: 'Oak Bar Set', qty: 2, unitPrice: 950),
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
          total: 7780,
          status: OrderStatus.needsPayment,
          notes:
              'Balance due before pickup. Park pavilion has limited power — pack spare extension cords and the heaters.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 36, unitPrice: 50),
            OrderLine(itemName: '6ft Round Tables', qty: 10, unitPrice: 250),
            OrderLine(itemName: 'White Linen 90"', qty: 14, unitPrice: 120),
            OrderLine(itemName: 'Bistro Heaters', qty: 4, unitPrice: 450),
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
          total: 2700,
          status: OrderStatus.outForDelivery,
          notes:
              'Narrow stairwell at the studio — carry tables flat. Eli picks up and returns the items himself.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 6, unitPrice: 50),
            OrderLine(itemName: '6ft Round Tables', qty: 3, unitPrice: 250),
            OrderLine(itemName: 'String Lights', qty: 2, unitPrice: 350),
            OrderLine(itemName: 'Oak Bar Set', qty: 1, unitPrice: 950),
          ],
          // Handed over = every handover requirement was met (the gate
          // would not have let it leave the shop otherwise).
          downPayment: 1350,
          downPaymentPaidAt: now.subtract(const Duration(days: 5)),
          downPaymentMethod: PaymentMethod.cash,
          remainingPaidAt: now.subtract(const Duration(days: 3)),
          remainingMethod: PaymentMethod.telebirr,
          collateralAmount: 600,
          collateralPaidAt: now.subtract(const Duration(days: 3)),
          collateralMethod: PaymentMethod.cash,
          idVerifiedAt: now.subtract(const Duration(days: 3)),
          signedName: 'Eli Marlow',
          signatureData: seededSignature(),
          signedAt: now.subtract(const Duration(days: 3)),
        ),
        RentalOrder(
          id: 'RW-2039',
          eventName: 'Brighton Arts Gala',
          customerName: 'Lena Ortiz',
          contactName: 'Lena Ortiz',
          createdAt: now.subtract(const Duration(days: 8)),
          eventDate: now.subtract(const Duration(days: 2)),
          itemCount: 31,
          total: 6330,
          status: OrderStatus.returned,
          notes:
              'Teardown happened the same night. Confirm glassware count against the manifest before restocking.',
          lineItems: const [
            OrderLine(itemName: 'Folding Chairs', qty: 14, unitPrice: 50),
            OrderLine(itemName: '6ft Round Tables', qty: 6, unitPrice: 250),
            OrderLine(itemName: 'String Lights', qty: 5, unitPrice: 350),
            OrderLine(itemName: 'White Linen 90"', qty: 4, unitPrice: 120),
            OrderLine(itemName: 'Oak Bar Set', qty: 2, unitPrice: 950),
          ],
          // Returned orders passed the handover gate — every line settled.
          downPayment: 3165,
          downPaymentPaidAt: now.subtract(const Duration(days: 8)),
          downPaymentMethod: PaymentMethod.cbeBirr,
          remainingPaidAt: now.subtract(const Duration(days: 4)),
          remainingMethod: PaymentMethod.cbeBirr,
          collateralAmount: 800,
          collateralPaidAt: now.subtract(const Duration(days: 4)),
          collateralMethod: PaymentMethod.cash,
        ),
      ];

  // ---------------------------------------------------------------- customers
  /// Contact book for the workspace. Rentals / lifetime spend / last
  /// booking are DERIVED from the seeded orders so every screen tells
  /// the same story (a customer's history can never contradict the
  /// order list).
  static List<Customer> customers(DateTime now) {
    final os = orders(now);
    Customer contact({
      required String id,
      required String name,
      required String company,
      required String email,
      required String phone,
      required Color avatarColor,
    }) {
      final mine = os.where((o) => o.customerName == name).toList();
      final spend = mine.fold<double>(0, (s, o) => s + o.total);
      final last = mine.isEmpty
          ? now
          : mine.map((o) => o.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      return Customer(
        id: id,
        name: name,
        company: company,
        email: email,
        phone: phone,
        rentals: mine.length,
        lifetimeSpend: spend,
        lastBooking: last,
        avatarColor: avatarColor,
      );
    }

    return [
      contact(
        id: 'CUS-001',
        name: 'Avery Harper',
        company: 'The Harper Wedding',
        email: 'avery@harperwed.com',
        phone: '+251 911 201 447',
        avatarColor: AppColors.avatarGreen,
      ),
      contact(
        id: 'CUS-002',
        name: 'Mia Chen',
        company: 'Northstar Events',
        email: 'mia@northstar.events',
        phone: '+251 912 883 201',
        avatarColor: AppColors.avatarTeal,
      ),
      contact(
        id: 'CUS-003',
        name: 'Tara Monroe',
        company: 'Monroe Family',
        email: 'tara.monroe@gmail.com',
        phone: '+251 913 340 998',
        avatarColor: AppColors.avatarOrange,
      ),
      contact(
        id: 'CUS-004',
        name: 'Eli Marlow',
        company: 'Marlow Studio',
        email: 'eli@marlow.studio',
        phone: '+251 914 771 662',
        avatarColor: AppColors.avatarPurple,
      ),
      contact(
        id: 'CUS-005',
        name: 'Lena Ortiz',
        company: 'Brighton Arts',
        email: 'lena@brightonarts.org',
        phone: '+251 915 418 223',
        avatarColor: AppColors.avatarBlue,
      ),
    ];
  }

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
        body: '**${jm.name}** recorded Telebirr payment of **Br 2,050**',
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
  // Revenue figures are Ethiopian Birr. The 5 seeded orders sum to
  // Br 28,630; the month-scale trend lines sit at ~10× that so the
  // charts and KPIs tell one consistent story.
  static List<RevenuePoint> revenueTrend(DateTime now) {
    final values = [19.0, 26.0, 22.0, 31.0, 28.0, 34.0, 41.0];
    return List.generate(
      values.length,
      (i) => RevenuePoint(
        day: now.subtract(Duration(days: (values.length - 1 - i) * 2)),
        value: values[i],
      ),
    );
  }

  /// Daily gross bookings for the owner earnings chart (last 12 days,
  /// in Br k). Sums to the month-to-date figure (289k).
  static List<RevenuePoint> earningsDaily(DateTime now) {
    final values = [
      19.0, 23.0, 21.0, 26.0, 22.0, 28.0, 24.0, 29.0, 20.0, 26.0, 24.0, 27.0,
    ];
    return List.generate(
      values.length,
      (i) => RevenuePoint(
        day: now.subtract(Duration(days: values.length - 1 - i)),
        value: values[i],
      ),
    );
  }

  /// Category revenue for the month — derived from the seeded order
  /// lines ×10 (the month has ~10× the five seeded bookings). Sums to
  /// 286,300 ≈ [grossRevenueMonth].
  static const List<CategoryRevenue> categoryRevenue = [
    CategoryRevenue(category: 'Seating', amount: 43000),
    CategoryRevenue(category: 'Tables', amount: 77500),
    CategoryRevenue(category: 'Lighting', amount: 52500),
    CategoryRevenue(category: 'Linens', amount: 28800),
    CategoryRevenue(category: 'Furniture', amount: 66500),
    CategoryRevenue(category: 'Outdoor', amount: 18000),
  ];

  // ---------------------------------------------------------------- dashboard
  static const double todaysRevenue = 24800;
  static const double yesterdaysRevenue = 19800;
  static const double revenueTrendPct = 25.3;
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
  static const double customerValueK = 5.7;
  static const double valueTrendPct = 14.2;
  static const int followUps = 7;

  static const double leadTimeGainPct = 18;
  static const double grossRevenueMonth = 289.0; // Br k
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
  // RW-2048 (7,720) + RW-2046 (7,780) — the two seeded open orders that
  // have not settled anything yet.
  static const double awaitingPayment = 15500;
  static const int awaitingPaymentOrders = 3;
  static const int outForDelivery = 6;
  static const int returnsToday = 8;
  static const int returnsLate = 2;

  static const int actionsToday = 24;
  static const int rentalUpdates = 12;
  static const int paymentsRecorded = 4;

  static const String businessCloseTime = '7:00 PM';
}
