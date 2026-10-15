import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../models/inventory_item.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/inventory_views.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/rows.dart';
import '../../screens/booking/new_booking_sheet.dart';
import '../../screens/inventory/item_adjust_dialog.dart';
import '../../widgets/filters.dart';
import '../../widgets/indicators.dart';

/// Operations overview (wide) + owner glance / compact variants.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 950;
    final now = DateTime.now();

    if (compact && state.isOwner) {
      return _OwnerCompactDashboard(state: state, now: now);
    }
    return _OperationsOverview(state: state, now: now, compact: compact);
  }
}

// ============================================================ operations view
class _OperationsOverview extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;
  final bool compact;

  const _OperationsOverview({
    required this.state,
    required this.now,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final wide = !compact;
    final snapshot = state.inventory.take(6).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 24, wide ? 30 : 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(dateLabel),
                    const SizedBox(height: 6),
                    Text('Operations overview',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 6),
                    const Text(
                        "Keep today's handoffs moving and every item accounted for.",
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              PrimaryButton(
                label: 'New rental booking',
                icon: Icons.add_rounded,
                onTap: () => showNewBookingSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI grid
          LayoutBuilder(builder: (context, c) {
            final cols = wide ? 4 : 2;
            const gap = 16.0;
            final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: "Today's revenue",
                    value: '\$2,480',
                    subtitle: 'vs. \$2,200 yesterday',
                    trailing: TrendChip(
                        text: '12.8%', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.event_available_outlined,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Active rentals',
                    value: '${Seed.activeRentals}',
                    subtitle: '6 events happening today',
                    trailing: TrendChip(
                        text: '4.2%', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Pending returns',
                    value: '${Seed.pendingReturns}',
                    subtitle: 'Keep an eye on 3 late items',
                    trailing: TrendChip(
                        text: '${Seed.returnsDueToday} due today',
                        positive: false),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppColors.blue,
                    iconBg: AppColors.blueBg,
                    label: "Today's dispatch",
                    value: '3:30 PM',
                    subtitle: 'Next: Oakwood Estate · 12 items',
                    trailing: TrendChip.flat(
                        text: 'On schedule', positive: true),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // main grid
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 12,
                    child: Column(
                      children: [
                        _SnapshotCard(
                            state: state, snapshot: snapshot, compact: false),
                        const SizedBox(height: 20),
                        _UpcomingPickups(state: state, now: now),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _RecentActivity(state: state),
                        const SizedBox(height: 20),
                        _WorkspaceHealth(state: state),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _SnapshotCard(state: state, snapshot: snapshot, compact: true),
            const SizedBox(height: 20),
            _RecentActivity(state: state),
            const SizedBox(height: 20),
            _UpcomingPickups(state: state, now: now),
            const SizedBox(height: 20),
            _WorkspaceHealth(state: state),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ snapshot card
class _SnapshotCard extends StatelessWidget {
  final WorkspaceState state;
  final List<InventoryItem> snapshot;
  final bool compact;

  const _SnapshotCard({
    required this.state,
    required this.snapshot,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Inventory snapshot',
      subtitle: 'Monitor availability before the next pickup.',
      action: LinkChip(
        label: 'View inventory',
        onTap: () => state.navigate(Section.inventory),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PopupFilterButton(
                value: state.categoryFilter,
                items: Seed.categories,
                onChanged: (v) => state.setCategoryFilter(v),
              ),
              const Spacer(),
              Text('${snapshot.length} items',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (compact)
            for (final item in state.filteredInventory.take(6))
              InventoryListTile(
                item: item,
                onTap: () => state.navigate(Section.inventory),
              )
          else
            InventoryTable(
              items: state.filteredInventory.take(6).toList(),
              compactMode: false,
              onRent: (item) => showNewBookingSheet(context, prefill: item),
              onEdit: (item) => showItemAdjustDialog(context, item),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- pickups card
class _UpcomingPickups extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;
  const _UpcomingPickups({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Upcoming pickups',
      subtitle: 'Next three bookings on the calendar',
      action: LinkChip(
        label: 'Open calendar',
        onTap: () => state.navigate(Section.orders),
      ),
      child: Column(
        children: [
          for (var i = 0; i < state.pickups.length; i++)
            PickupRow(
              pickup: state.pickups[i],
              now: now,
              showDivider: i < state.pickups.length - 1,
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- activity card
class _RecentActivity extends StatelessWidget {
  final WorkspaceState state;
  const _RecentActivity({required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = state.activity.take(4).toList();
    return SectionCard(
      icon: Icons.show_chart,
      title: 'Recent activity',
      subtitle: "What's happening in the workspace.",
      action: const Icon(Icons.more_horiz, size: 20, color: AppColors.textMuted),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ActivityRow(entry: entries[i], showDivider: false),
            ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: LinkChip(
              label: 'View all activity',
              onTap: () => state.navigate(Section.activity),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- health card
class _WorkspaceHealth extends StatelessWidget {
  final WorkspaceState state;
  const _WorkspaceHealth({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Workspace health'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Running smoothly',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: AppColors.greenBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.green),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const HealthBar(fraction: 0.98),
          const SizedBox(height: 10),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('24 active rentals',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textMuted)),
                Text('98% on time',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Dot(color: AppColors.green),
                SizedBox(width: 8),
                Text('Sync is up to date',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textMuted)),
                SizedBox(width: 18),
                Text('Just now',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================== owner compact
class _OwnerCompactDashboard extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;

  const _OwnerCompactDashboard({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final entries = state.activity.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(DateFormat('EEEE, MMMM d').format(now)),
                    const SizedBox(height: 5),
                    Text('Welcome back, Owner',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    const Text("Here's the pulse of Riverside Events.",
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const InitialsAvatar(
                  initials: 'OW',
                  color: AppColors.avatarIndigo,
                  size: 42,
                  fontSize: 14),
            ],
          ),
          const SizedBox(height: 18),

          // business open banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.greenBg.withOpacity(0.55),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.greenBg),
            ),
            child: Row(
              children: [
                const Dot(color: AppColors.green),
                const SizedBox(width: 9),
                const Text('Business Open',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green)),
                const SizedBox(width: 12),
                Container(width: 1, height: 14, color: AppColors.greenBg),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Closes at ${Seed.businessCloseTime}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppColors.textBody)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.green),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Today at a glance
          Row(
            children: [
              const Text('Today at a glance',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const Spacer(),
              LinkChip(
                label: 'Details',
                onTap: () => state.navigate(Section.orders),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(
            height: 148,
            child: Row(
              children: [
                Expanded(
                  child: KpiTileMini(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: "Today's revenue",
                    value: '\$2,480',
                    subtitle: 'vs. yesterday',
                    trailing: TrendChip(text: '12.8%', positive: true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: KpiTileMini(
                    icon: Icons.event_available_outlined,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Active rentals',
                    value: '24',
                    subtitle: 'since yesterday',
                    trailing: TrendChip(text: '+4', positive: true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: KpiTileMini(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Pending returns',
                    value: '8',
                    subtitle: 'today',
                    trailing: TrendChip(
                        text: '2 due', positive: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Live activity
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppShadow.card(opacity: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text('Live activity',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                    ),
                    StatusBadge.custom(
                      label: 'Live',
                      fg: AppColors.green,
                      bg: AppColors.greenBg,
                      dot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text('Employee actions, in real time.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textMuted)),
                const SizedBox(height: 16),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: ActivityRow(entry: e, showDivider: false),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkChip(
                    label: 'View activity log',
                    onTap: () => state.navigate(Section.activity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Next dispatch
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppShadow.card(opacity: 0.04),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconChipLite(
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.blue,
                        bg: AppColors.blueBg,
                        size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow('Next dispatch'),
                          SizedBox(height: 3),
                          Text('Oakwood Estate',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    Text('3:30 PM',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
                SizedBox(height: 14),
                Divider(),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Sat, Oct 18',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
                    SizedBox(width: 14),
                    Icon(Icons.inventory_2_outlined,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('12 items',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
                    SizedBox(width: 14),
                    Icon(Icons.person_outline,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Mia Chen',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
