import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/density.dart';
import '../../models/customer.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/filters.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_status_style.dart';
import '../booking/new_booking_sheet.dart';
import '../customers/customer_detail_screen.dart';
import '../../core/palette.dart';

/// Full order detail — opened by tapping any order row/card, task or
/// dispatch run. Shows the quoted manifest, delivery notes, a payment
/// summary and the status flow with real actions.
class OrderDetailScreen extends StatelessWidget {
  final RentalOrder order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    // always read the live copy of the order
    final live = state.orderById(order.id) ?? order;
    final df = DateFormat('EEE, MMM d, yyyy');
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compact = Density.compact(context);

    final days = live.eventDate
        .difference(DateTime.now())
        .inDays;

    final customer = state.customerByName(live.customerName);

    final header = SectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Order ${live.id}',
      subtitle: 'Created ${df.format(live.createdAt)} · ${live.status.label}',
      action: StatusBadge(
        label: live.status.label,
        fg: live.status.fg,
        bg: live.status.bg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(live.eventName,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppPalette.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MetaFact(
                  icon: Icons.event_outlined,
                  label: 'Event date',
                  value: df.format(live.eventDate)),
              _MetaFact(
                  icon: Icons.schedule_rounded,
                  label: 'Timeline',
                  value: days > 0
                      ? 'In $days days'
                      : days == 0
                          ? 'Today'
                          : '${-days} days ago'),
              _MetaFact(
                  icon: Icons.inventory_2_outlined,
                  label: 'Items',
                  value: '${live.itemCount} on this order'),
              _MetaFact(
                  icon: Icons.contact_phone_outlined,
                  label: 'Contact',
                  value: live.contactName),
            ],
          ),
        ],
      ),
    );

    final manifest = SectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Item manifest',
      subtitle: live.lineItems.isEmpty
          ? 'No line items recorded for this order.'
          : '${live.lineItems.length} line(s) · quoted event pricing',
      child: live.lineItems.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('This order was created without a manifest.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppPalette.muted)),
            )
          : Column(
              children: [
                for (var i = 0; i < live.lineItems.length; i++)
                  StaggerIn(
                    index: i,
                    child: _LineRow(
                      line: live.lineItems[i],
                      showDivider: i < live.lineItems.length - 1,
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('TOTAL · ${live.itemCount} items',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppPalette.muted)),
                    ),
                    Text(money.format(live.total),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink)),
                  ],
                ),
              ],
            ),
    );

    final notesCard = SectionCard(
      icon: Icons.sticky_note_2_outlined,
      title: 'Delivery notes',
      subtitle: 'Captured at booking time.',
      child: Text(
        live.notes.isEmpty
            ? 'No notes on this order yet.'
            : live.notes,
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            height: 1.5,
            color: live.notes.isEmpty ? AppPalette.muted : AppPalette.body),
      ),
    );

    final payment = _PaymentCard(order: live);

    final customerCard = SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Customer',
      subtitle: 'Who this booking belongs to.',
      action: customer == null
          ? null
          : LinkChip(
              label: 'View profile',
              onTap: () => _openCustomer(context, customer),
            ),
      child: customer == null
          ? Text(
              '${live.customerName} is not in the directory yet — added bookings will link automatically.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  color: AppPalette.muted))
          : HoverLift(
              onTap: () => _openCustomer(context, customer),
              child: _CustomerStrip(customer: customer),
            ),
    );

    final actions = _StatusActionsCard(order: live);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 14),
        if (wide) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 12,
                  child: Column(
                    children: [
                      manifest,
                      const SizedBox(height: 14),
                      notesCard,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      payment,
                      const SizedBox(height: 14),
                      customerCard,
                      const SizedBox(height: 14),
                      actions,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          manifest,
          const SizedBox(height: 14),
          payment,
          const SizedBox(height: 14),
          notesCard,
          const SizedBox(height: 14),
          customerCard,
          const SizedBox(height: 14),
          actions,
        ],
        const SizedBox(height: 6),
        if (!compact) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              OutlineButton(
                label: 'Book similar order',
                icon: Icons.copy_rounded,
                onTap: () => showNewBookingSheet(context),
              ),
              const SizedBox(width: 10),
              OutlineButton(
                label: 'View all orders',
                icon: Icons.receipt_long_outlined,
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ],
    );

    return DetailPage(
      eyebrow: 'Workspace / Orders / ${live.id}',
      title: live.eventName,
      subtitle: 'Status updates write straight to the activity log.',
      icon: Icons.receipt_long_outlined,
      body: body,
    );
  }

  void _openCustomer(BuildContext context, Customer customer) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CustomerDetailScreen(customer: customer),
    ));
  }
}

// ----------------------------------------------------------------- pieces
class _MetaFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaFact(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppPalette.muted),
        const SizedBox(width: 6),
        Text('$label  ',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppPalette.muted)),
        Text(value,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  final OrderLine line;
  final bool showDivider;
  const _LineRow({required this.line, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.itemName,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.ink)),
                    Text('${money.format(line.unitPrice)} / unit',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: AppPalette.muted)),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('×${line.qty}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.body)),
              ),
              SizedBox(
                width: 74,
                child: Text(money.format(line.lineTotal),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final RentalOrder order;
  const _PaymentCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final paid = order.status != OrderStatus.needsPayment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paid ? AppPalette.greenBg : AppPalette.amberBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: (paid ? AppPalette.green : AppPalette.amber)
                .withOpacity(AppPalette.dark ? 0.3 : 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  paid
                      ? Icons.check_circle_rounded
                      : Icons.account_balance_wallet_outlined,
                  size: 17,
                  color: paid ? AppPalette.green : AppPalette.amber),
              const SizedBox(width: 8),
              Text(paid ? 'Payment settled' : 'Payment pending',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: paid ? AppPalette.green : AppPalette.amber)),
            ],
          ),
          const SizedBox(height: 12),
          Text(money.format(order.total),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppPalette.ink)),
          const SizedBox(height: 4),
          Text(
            paid
                ? 'Nothing outstanding on this order.'
                : 'Follow up with ${order.contactName} before the event date.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppPalette.body),
          ),
        ],
      ),
    );
  }
}

class _CustomerStrip extends StatelessWidget {
  final Customer customer;
  const _CustomerStrip({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.fill.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: Row(
        children: [
          InitialsAvatar(
              initials: customer.initials,
              color: customer.avatarColor,
              size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink)),
                Text('${customer.company} · ${customer.rentals} rentals',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: AppPalette.muted),
        ],
      ),
    );
  }
}

/// Real status transitions — each button writes the change to the store
/// and lands in the activity log.
class _StatusActionsCard extends StatelessWidget {
  final RentalOrder order;
  const _StatusActionsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final next = _nextStatuses(order.status);

    return SectionCard(
      icon: Icons.bolt_rounded,
      title: 'Update status',
      subtitle: 'Advances this order through the rental lifecycle.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in next)
            OutlineButton(
              label: s.label,
              icon: _statusIcon(s),
              fg: s.fg,
              onTap: () {
                state.updateOrderStatus(order, s);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${order.id} marked “${s.label}”'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
          if (next.isEmpty)
            Text('This order is fully closed — nothing left to do.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppPalette.muted)),
        ],
      ),
    );
  }

  /// Sensible forward transitions from the current status.
  List<OrderStatus> _nextStatuses(OrderStatus s) => switch (s) {
        OrderStatus.confirmed => [
            OrderStatus.preparing,
            OrderStatus.outForDelivery,
            OrderStatus.needsPayment
          ],
        OrderStatus.preparing =>
          [OrderStatus.outForDelivery, OrderStatus.needsPayment],
        OrderStatus.outForDelivery =>
          [OrderStatus.needsPayment, OrderStatus.returned],
        OrderStatus.needsPayment => [OrderStatus.confirmed, OrderStatus.returned],
        OrderStatus.returned => const [],
      };

  IconData _statusIcon(OrderStatus s) => switch (s) {
        OrderStatus.confirmed => Icons.check_rounded,
        OrderStatus.preparing => Icons.inventory_2_outlined,
        OrderStatus.outForDelivery => Icons.local_shipping_outlined,
        OrderStatus.needsPayment => Icons.payments_outlined,
        OrderStatus.returned => Icons.assignment_return_outlined,
      };
}

/// KPI card reused by the orders screen to jump here.
void openOrderDetail(BuildContext context, RentalOrder order) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => OrderDetailScreen(order: order),
  ));
}
