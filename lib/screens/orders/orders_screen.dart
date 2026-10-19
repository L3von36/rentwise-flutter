import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../core/app_colors.dart'; // AppRadius
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_status_style.dart';
import '../booking/new_booking_sheet.dart';
import 'order_detail_screen.dart';
import '../../core/palette.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;
    final compactList = width < 860;

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text('Orders',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: Density.compact(context) ? 17 : 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppPalette.ink)),
              ),
              PrimaryButton(
                label: 'New rental booking',
                icon: Icons.add_rounded,
                onTap: () => showNewBookingSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _ListCard(
            child: Column(
              children: [
                // status filters — the one filter system, live counts
                _StatusFilterRow(state: state),
                const SizedBox(height: 12),
                if (compactList)
                  for (final order in state.filteredOrders)
                    _OrderCard(
                      order: order,
                      onAction: (s) => state.updateOrderStatus(order, s),
                    )
                else ...[
                  _OrderHeader(),
                  for (final order in state.filteredOrders)
                    _OrderRow(
                      order: order,
                      onAction: (s) => state.updateOrderStatus(order, s),
                    ),
                ],
                if (state.filteredOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Text('No orders in this view.',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            color: AppPalette.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain list surface — the page title + status chips are the header.
class _ListCard extends StatelessWidget {
  final Widget child;
  const _ListCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Density.compact(context) ? 14 : 16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: child,
    );
  }
}

/// Status filter chips under the tabs: one per order status plus an All
/// bucket, each with a live count scoped to the active tab (so narrowing
/// never hides the other buckets' counts). Horizontally scrollable so the
/// full vocabulary fits a phone.
class _StatusFilterRow extends StatelessWidget {
  final WorkspaceState state;
  const _StatusFilterRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final tabOrders = state.tabOrders;
    final selected = state.orderStatusFilter;

    Widget chipFor(OrderStatus status) {
      final active = selected == status;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _StatusChip(
          label: status.label,
          count: tabOrders.where((o) => o.status == status).length,
          fg: status.fg,
          bg: status.bg,
          selected: active,
          onTap: () => state.setOrderStatusFilter(active ? null : status),
        ),
      );
    }

    return SizedBox(
      width: double.infinity, // left-align within the centered SectionCard
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StatusChip(
                label: 'All',
                count: tabOrders.length,
                fg: AppPalette.primary,
                bg: AppPalette.primarySoft,
                selected: selected == null,
                onTap: () => state.setOrderStatusFilter(null),
              ),
            ),
            for (final status in OrderStatus.values) chipFor(status),
          ],
        ),
      ),
    );
  }
}

/// One selectable status chip: status dot + `label · count`. Selected chips
/// fill with the status wash and read in the status color; idle ones sit on
/// the neutral fill — both modes resolve through [AppPalette].
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color fg;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.fg,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : AppPalette.fill,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? fg.withOpacity(0.4) : AppPalette.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Dot(color: selected ? fg : AppPalette.faint, size: 6),
            const SizedBox(width: 5),
            Text('$label · $count',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? fg : AppPalette.muted)),
          ],
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  static const _flexes = [3, 4, 3, 2, 2, 3, 1];

  static const _labels = [
    'Order',
    'Customer',
    'Event date',
    'Items',
    'Total',
    'Status',
    '',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              flex: _flexes[i],
              child: Text(
                _labels[i].toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppPalette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final RentalOrder order;
  final ValueChanged<OrderStatus> onAction;
  const _OrderRow({required this.order, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    return HoverFill(
      onTap: () => openOrderDetail(context, order),
      radius: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.stroke)),
        ),
        child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.id}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(order.contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(df.format(order.eventDate),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppPalette.body)),
          ),
          Expanded(
            flex: 2,
            child: Text('${order.itemCount} items',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppPalette.body)),
          ),
          Expanded(
            flex: 2,
            child: Text('\$${NumberFormat('#,##0').format(order.total)}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink)),
          ),
          Expanded(
            flex: 3,
            child: StatusBadge(
              label: order.status.label,
              fg: order.status.fg,
              bg: order.status.bg,
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: _OrderMenu(order: order, onAction: onAction),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RentalOrder order;
  final ValueChanged<OrderStatus> onAction;
  const _OrderCard({required this.order, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    return HoverFill(
      onTap: () => openOrderDetail(context, order),
      radius: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppPalette.stroke)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${order.id}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary)),
                const Spacer(),
                StatusBadge(
                  label: order.status.label,
                  fg: order.status.fg,
                  bg: order.status.bg,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.eventName,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink)),
            const SizedBox(height: 3),
            Text('${order.contactName} · ${order.itemCount} items',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppPalette.muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 14, color: AppPalette.muted),
                const SizedBox(width: 5),
                Text(df.format(order.eventDate),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppPalette.muted)),
                const Spacer(),
                Text('\$${NumberFormat('#,##0').format(order.total)}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink)),
                const SizedBox(width: 10),
                _OrderMenu(order: order, onAction: onAction),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderMenu extends StatelessWidget {
  final RentalOrder order;
  final ValueChanged<OrderStatus> onAction;
  const _OrderMenu({required this.order, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Order actions',
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: AppPalette.stroke),
      ),
      onSelected: (v) {
        switch (v) {
          case 'details':
            openOrderDetail(context, order);
          case 'confirmed':
            onAction(OrderStatus.confirmed);
          case 'outForDelivery':
            onAction(OrderStatus.outForDelivery);
          case 'returned':
            onAction(OrderStatus.returned);
          case 'needsPayment':
            onAction(OrderStatus.needsPayment);
        }
      },
      offset: const Offset(0, 8),
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'details',
            height: 38,
            child: Row(
              children: [
                Icon(Icons.open_in_new_rounded, size: 15),
                SizedBox(width: 8),
                Text('View details',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 13)),
              ],
            )),
        const PopupMenuItem(
            value: 'confirmed',
            height: 38,
            child: Text('Mark confirmed',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily, fontSize: 13))),
        const PopupMenuItem(
            value: 'outForDelivery',
            height: 38,
            child: Text('Mark handed over (pickup)',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily, fontSize: 13))),
        const PopupMenuItem(
            value: 'returned',
            height: 38,
            child: Text('Mark returned',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily, fontSize: 13))),
        const PopupMenuItem(
            value: 'needsPayment',
            height: 38,
            child: Text('Flag needs payment',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily, fontSize: 13))),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppPalette.stroke),
        ),
        child: Icon(Icons.more_horiz,
            size: 16, color: AppPalette.muted),
      ),
    );
  }
}
