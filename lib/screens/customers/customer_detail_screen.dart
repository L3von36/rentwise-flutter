import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/customer.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/filters.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_status_style.dart';
import '../booking/new_booking_sheet.dart';
import '../orders/order_detail_screen.dart';
import '../../core/palette.dart';

/// Customer 360 — profile, contact actions, spend stats and every order
/// they have ever placed (tap one to open its detail).
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final df = DateFormat('MMM d, yyyy');
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    // live copy + their order history
    final live = state.customers.firstWhere(
      (c) => c.id == customer.id,
      orElse: () => customer,
    );
    final orders = state.ordersForCustomer(live.name);
    final openOrders = orders.where((o) => o.status.isOpen).length;

    final profile = SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Profile',
      subtitle: '${live.company} · last booking ${df.format(live.lastBooking)}',
      action: LinkChip(
        label: 'New booking',
        onTap: () => showNewBookingSheet(context, prefillCustomer: live.name),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                  initials: live.initials,
                  color: live.avatarColor,
                  size: 46,
                  fontSize: 15),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(live.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: AppPalette.ink)),
                        ),
                        if (live.isRepeat) ...[
                          const SizedBox(width: 8),
                          StatusBadge.custom(
                            label: 'Repeat',
                            fg: AppPalette.green,
                            bg: AppPalette.greenBg,
                            dot: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(live.company,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            color: AppPalette.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: live.email,
            tapLabel: 'Copy email',
            onTap: () => _copy(context, live.email, 'Email copied'),
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: live.phone,
            tapLabel: 'Copy phone',
            onTap: () => _copy(context, live.phone, 'Phone number copied'),
          ),
        ],
      ),
    );

    final stats = LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 520 ? 2 : 4;
      const gap = 10.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.repeat_rounded,
              iconColor: AppPalette.primary,
              iconBg: AppPalette.primarySoft,
              label: 'Rentals',
              value: '${live.rentals}',
              subtitle: '$openOrders open right now',
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.payments_outlined,
              iconColor: AppPalette.green,
              iconBg: AppPalette.greenBg,
              label: 'Lifetime spend',
              value: money.format(live.lifetimeSpend),
              subtitle: 'total to date',
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.event_available_outlined,
              iconColor: AppPalette.purple,
              iconBg: AppPalette.purpleBg,
              label: 'Avg per booking',
              value: live.rentals == 0
                  ? '—'
                  : money.format(live.lifetimeSpend / live.rentals),
              subtitle: 'realized value',
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.schedule_rounded,
              iconColor: AppPalette.amber,
              iconBg: AppPalette.amberBg,
              label: 'Last booking',
              value: df.format(live.lastBooking),
              subtitle: 'most recent',
            ),
          ),
        ],
      );
    });

    final history = SectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Order history',
      subtitle: orders.isEmpty
          ? 'No orders yet — their first booking will show up here.'
          : '${orders.length} ${orders.length == 1 ? 'booking' : 'bookings'} · newest first',
      child: orders.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                  'No orders yet.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppPalette.muted)),
            )
          : Column(
              children: [
                for (var i = 0; i < orders.length; i++)
                  StaggerIn(
                    index: i,
                    child: HoverFill(
                      onTap: () => openOrderDetail(context, orders[i]),
                      child: _HistoryRow(order: orders[i]),
                    ),
                  ),
              ],
            ),
    );

    final insights = _MiniInsights(orders: orders);

    return DetailPage(
      eyebrow: 'Customers / ${live.name}',
      title: live.name,
      icon: Icons.person_outline_rounded,
      iconColor: live.avatarColor,
      iconBg: AppPalette.fill,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          profile,
          const SizedBox(height: 14),
          stats,
          const SizedBox(height: 14),
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 12,
                    child: Column(
                      children: [
                        history,
                        const SizedBox(height: 14),
                        insights,
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            history,
            const SizedBox(height: 14),
            insights,
          ],
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

void openCustomerDetail(BuildContext context, Customer customer) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => CustomerDetailScreen(customer: customer),
  ));
}

// ----------------------------------------------------------------- pieces
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tapLabel;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.tapLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverFill(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppPalette.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.body)),
            ),
            Text(tapLabel,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary)),
            const SizedBox(width: 4),
            Icon(Icons.copy_rounded, size: 13, color: AppPalette.primary),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final RentalOrder order;
  const _HistoryRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.id} · ${order.eventName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(
                    '${df.format(order.eventDate)} · ${order.itemCount} items',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(money.format(order.total),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink)),
          const SizedBox(width: 10),
          StatusBadge.custom(
            label: order.status.label,
            fg: order.status.fg,
            bg: order.status.bg,
            fontSize: 10.5,
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.faint),
        ],
      ),
    );
  }
}

/// Tiny derived insights card — busiest category, on-time history.
class _MiniInsights extends StatelessWidget {
  final List<RentalOrder> orders;
  const _MiniInsights({required this.orders});

  @override
  Widget build(BuildContext context) {
    final items =
        orders.fold<int>(0, (s, o) => s + o.itemCount);
    final closed =
        orders.where((o) => o.status == OrderStatus.returned).length;

    return SectionCard(
      icon: Icons.insights_outlined,
      title: 'Quick insights',
      child: Row(
        children: [
          Expanded(
            child: _FactTile(
                label: 'Items rented',
                value: '$items'),
          ),
          Expanded(
            child: _FactTile(
                label: 'Completed',
                value: orders.isEmpty
                    ? '—'
                    : '${(closed / orders.length * 100).round()}%'),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  final String label;
  final String value;
  const _FactTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppPalette.ink)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppPalette.muted)),
        ],
      ),
    );
  }
}
