import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/kpi_card.dart';
import '../booking/new_booking_sheet.dart';
import '../../widgets/indicators.dart';

/// Status pill colors for orders.
extension _OrderStatusStyle on OrderStatus {
  Color get fg => switch (this) {
        OrderStatus.preparing => AppColors.blue,
        OrderStatus.confirmed => AppColors.green,
        OrderStatus.needsPayment => AppColors.amber,
        OrderStatus.outForDelivery => AppColors.purple,
        OrderStatus.returned => AppColors.green,
      };

  Color get bg => switch (this) {
        OrderStatus.preparing => AppColors.blueBg,
        OrderStatus.confirmed => AppColors.greenBg,
        OrderStatus.needsPayment => AppColors.amberBg,
        OrderStatus.outForDelivery => AppColors.purpleBg,
        OrderStatus.returned => AppColors.greenBg,
      };
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;
    final compactList = width < 860;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconChipLite(
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  size: 40),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Workspace / Orders'),
                    SizedBox(height: 4),
                    Text('Orders',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppColors.textDark)),
                  ],
                ),
              ),
              PrimaryButton(
                label: 'New rental booking',
                icon: Icons.add_rounded,
                onTap: () => showNewBookingSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Coordinate upcoming events, deliveries, and returns.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppColors.textMuted)),
          const SizedBox(height: 22),

          LayoutBuilder(builder: (context, c) {
            final cols = width < 1100 ? 2 : 4;
            const gap = 16.0;
            final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.receipt_long_outlined,
                    iconColor: AppColors.blue,
                    iconBg: AppColors.blueBg,
                    label: 'Open orders',
                    value: '${Seed.openOrders}',
                    subtitle: 'Since yesterday',
                    trailing: TrendChip(text: '+4', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Awaiting payment',
                    value: '\$4,910',
                    subtitle: 'Follow up today',
                    trailing: TrendChip(
                        text: '${Seed.awaitingPaymentOrders} orders',
                        positive: false),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Out for delivery',
                    value: '${Seed.outForDelivery}',
                    subtitle: 'On schedule',
                    trailing: TrendChip(text: '100%', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Returns today',
                    value: '${Seed.returnsToday}',
                    subtitle: 'Needs attention',
                    trailing: TrendChip(
                        text: '${Seed.returnsLate} late', positive: false),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 20),

          SectionCard(
            icon: Icons.receipt_long_outlined,
            title: 'Rental orders',
            subtitle: 'One view for the full order lifecycle.',
            child: Column(
              children: [
                // tabs
                Row(
                  children: [
                    _OrderTabs(
                      tabs: const ['All orders', 'Upcoming', 'Completed'],
                      selected: state.orderTab,
                      onChanged: state.setOrderTab,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (compactList)
                  for (final order in state.filteredOrders)
                    _OrderCard(order: order, onAction: (s) => state.updateOrderStatus(order, s))
                else ...[
                  _OrderHeader(),
                  for (final order in state.filteredOrders)
                    _OrderRow(
                      order: order,
                      onAction: (s) => state.updateOrderStatus(order, s),
                    ),
                ],
                if (state.filteredOrders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Text('No orders in this view.',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTabs extends StatelessWidget {
  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onChanged;
  const _OrderTabs({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs)
            GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tab == selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: tab == selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(tab,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tab == selected
                          ? AppColors.textDark
                          : AppColors.textMuted,
                    )),
              ),
            ),
        ],
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
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textMuted,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.id}',
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text('Created ${df.format(order.createdAt)}',
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppColors.textFaint)),
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
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(order.contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(df.format(order.eventDate),
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppColors.textBody)),
          ),
          Expanded(
            flex: 2,
            child: Text('${order.itemCount} items',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppColors.textBody)),
          ),
          Expanded(
            flex: 2,
            child: Text('\$${NumberFormat('#,##0').format(order.total)}',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${order.id}',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
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
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 3),
          Text('${order.contactName} · ${order.itemCount} items',
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppColors.textMuted)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(df.format(order.eventDate),
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppColors.textMuted)),
              const Spacer(),
              Text('\$${NumberFormat('#,##0').format(order.total)}',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(width: 10),
              _OrderMenu(order: order, onAction: onAction),
            ],
          ),
        ],
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      onSelected: (v) {
        switch (v) {
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
            value: 'confirmed',
            height: 38,
            child: Text('Mark confirmed',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily, fontSize: 13))),
        const PopupMenuItem(
            value: 'outForDelivery',
            height: 38,
            child: Text('Mark out for delivery',
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
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Icon(Icons.more_horiz,
            size: 16, color: AppColors.textMuted),
      ),
    );
  }
}
