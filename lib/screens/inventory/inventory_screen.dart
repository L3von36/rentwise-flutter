import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../data/catalog.dart';
import '../../models/inventory_item.dart';
import '../../services/csv_export.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/inventory_views.dart';
import '../../widgets/kpi_card.dart';
import '../booking/new_booking_sheet.dart';
import 'item_adjust_dialog.dart';
import '../../widgets/filters.dart';
import '../../widgets/indicators.dart';
import '../../core/palette.dart';

/// Which metric a KPI drill-in dialog breaks down by category.
enum _BreakdownMode { total, available, onRent }

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;
    final compactList = width < 860;

    final items = state.filteredInventory;
    final availablePct =
        state.totalUnits == 0 ? 0 : (state.availableUnits / state.totalUnits * 100);
    final onRentPct =
        state.totalUnits == 0 ? 0 : (state.onRentUnits / state.totalUnits * 100);

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
                child: Text('Inventory',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: Density.compact(context) ? 17 : 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppPalette.ink)),
              ),
              // Adding catalog items is a purchasing decision — owner-only.
              // Employees adjust stock counts from the table instead.
              if (state.isOwner)
                PrimaryButton(
                  label: 'Add inventory',
                  icon: Icons.add_rounded,
                  onTap: () => _showAddDialog(context),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // KPI grid — each card drills into ITS OWN metric, never the
          // same screen: totals / availability / on-rent / watch list.
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
                  child: KpiCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppPalette.primary,
                    iconBg: AppPalette.primarySoft,
                    label: 'Total items',
                    value: '${state.totalUnits}',
                    subtitle: 'All catalog units',
                    trailing: TrendChip.flat(
                        text: '${state.inventory.length} lines'),
                    onTap: () => _showCategoryBreakdown(
                        context, _BreakdownMode.total),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppPalette.green,
                    iconBg: AppPalette.greenBg,
                    label: 'Available now',
                    value: '${state.availableUnits}',
                    subtitle: 'Ready to book',
                    trailing: TrendChip(
                        text: '${availablePct.toStringAsFixed(0)}%',
                        positive: true),
                    onTap: () => _showCategoryBreakdown(
                        context, _BreakdownMode.available),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppPalette.amber,
                    iconBg: AppPalette.amberBg,
                    label: 'On rent',
                    value: '${state.onRentUnits}',
                    subtitle: 'With customers now',
                    trailing: TrendChip(
                        text: '${onRentPct.toStringAsFixed(1)}%',
                        positive: false),
                    onTap: () =>
                        _showCategoryBreakdown(context, _BreakdownMode.onRent),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.build_circle_outlined,
                    iconColor: AppPalette.blue,
                    iconBg: AppPalette.blueBg,
                    label: 'Needs attention',
                    value: '${state.attentionItems}',
                    subtitle: 'In maintenance',
                    trailing: const TrendChip.flat(text: 'Watch list'),
                    onTap: () => _showAttentionList(context),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          // main card
          SectionCard(
            icon: Icons.inventory_2_outlined,
            title: 'All inventory',
            action: OutlineButton(
              label: 'Export CSV',
              icon: Icons.file_download_outlined,
              onTap: () => showCsvExport(
                context,
                title: 'Inventory',
                filename: 'inventory.csv',
                header: const [
                  'id', 'name', 'category', 'total_stock', 'available',
                  'on_rent', 'status', 'rate_per_day'
                ],
                rows: state.inventory
                    .map((i) => [
                          i.id,
                          i.name,
                          i.category,
                          '${i.totalStock}',
                          '${i.available}',
                          '${i.onRentUnits}',
                          i.status.label,
                          i.ratePerDay.toStringAsFixed(2),
                        ])
                    .toList(),
              ),
            ),
            child: Column(
              children: [
                // search + filter row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: state.setInventoryQuery,
                        decoration: InputDecoration(
                          hintText: 'Search inventory',
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18, color: AppPalette.muted),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 42),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupFilterButton(
                      value: state.categoryFilter,
                      items: Catalog.categories,
                      onChanged: state.setCategoryFilter,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status chips — live counts per lifecycle state. Tap to
                // narrow the table; tap again to clear.
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _StatusChip(
                            label: 'All statuses',
                            count: state.inventory.length,
                            fg: AppPalette.primary,
                            bg: AppPalette.primarySoft,
                            selected:
                                state.inventoryStatusFilter == null,
                            onTap: () =>
                                state.setInventoryStatusFilter(null),
                          ),
                        ),
                        for (final status in ItemStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _StatusChip(
                              label: status.label,
                              count: state.countByStatus(status),
                              fg: status.fg,
                              bg: status.bg,
                              selected:
                                  state.inventoryStatusFilter == status,
                              onTap: () => state.setInventoryStatusFilter(
                                  state.inventoryStatusFilter == status
                                      ? null
                                      : status),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${items.length} of ${state.inventory.length} items',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppPalette.muted)),
                ),
                const SizedBox(height: 6),
                if (compactList)
                  for (final item in items)
                    InventoryListTile(
                      item: item,
                      onTap: () => showItemAdjustDialog(context, item),
                    )
                else
                  InventoryTable(
                    items: items,
                    onRent: (item) =>
                        showNewBookingSheet(context, prefill: item),
                    onEdit: (item) => showItemAdjustDialog(context, item),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Text('No items match your filters.',
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

  /// Live per-category drill-in for the KPI cards. Each mode surfaces a
  /// DIFFERENT metric so the three cards never show the same screen:
  ///  - total     : every unit owned, per category
  ///  - available : bookable units per category (maintenance excluded)
  ///  - onRent    : units out with customers, per category
  /// The dialog can also push its slice straight into the table below
  /// via the status chips.
  void _showCategoryBreakdown(BuildContext context, _BreakdownMode mode) {
    final state = context.read<WorkspaceState>();

    int metric(InventoryItem i) => switch (mode) {
          _BreakdownMode.total => i.totalStock,
          _BreakdownMode.available =>
            i.maintenance ? 0 : i.available.clamp(0, i.totalStock),
          _BreakdownMode.onRent => i.onRentUnits,
        };

    final byCategory = <String, List<InventoryItem>>{};
    for (final item in state.inventory) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }
    final categories = byCategory.keys.toList()..sort();
    final maxUnits = byCategory.values
        .map((l) => l.fold<int>(0, (s, i) => s + metric(i)))
        .fold(0, math.max);
    final grandTotal =
        byCategory.values.fold<int>(0, (s, l) => s + l.fold(0, (s, i) => s + metric(i)));

    final (title, subtitle) = switch (mode) {
      _BreakdownMode.total => (
        'Total items — $grandTotal units',
        'Every unit you own, grouped by category'
      ),
      _BreakdownMode.available => (
        'Available now — $grandTotal units',
        'Bookable units per category (maintenance items are not counted)'
      ),
      _BreakdownMode.onRent => (
        'On rent — $grandTotal units',
        'Units out with customers, grouped by category'
      ),
    };

    final barColor = switch (mode) {
      _BreakdownMode.total => AppPalette.primary,
      _BreakdownMode.available => AppPalette.green,
      _BreakdownMode.onRent => AppPalette.amber,
    };

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppPalette.muted)),
              const SizedBox(height: 14),
              if (categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('No inventory yet.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppPalette.muted)),
                ),
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(category,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.ink)),
                          ),
                          Text(
                              '${byCategory[category]!.fold<int>(0, (s, i) => s + metric(i))} units',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.5,
                                  color: AppPalette.muted)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0,
                            end: maxUnits == 0
                                ? 0.0
                                : byCategory[category]!
                                        .fold<int>(
                                            0, (s, i) => s + metric(i)) /
                                    maxUnits),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppPalette.fill,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: t,
                            child: Container(
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (mode == _BreakdownMode.onRent)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                state.setInventoryStatusFilter(ItemStatus.rentedOut);
              },
              child: Text('Show rented items in the list',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppPalette.primary)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Close',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppPalette.body)),
          ),
        ],
      ),
    );
  }

  /// The items that need attention right now (low availability).
  void _showAttentionList(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final watch = state.inventory
        .where((i) => i.needsAttention)
        .toList()
      ..sort((a, b) => a.availabilityFraction.compareTo(b.availabilityFraction));

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Needs attention',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: watch.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Nothing needs attention — all healthy.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppPalette.muted)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in watch)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: IconChipLite(
                            icon: item.icon,
                            color: AppPalette.amber,
                            bg: AppPalette.amberBg,
                            size: 30),
                        title: Text(item.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(item.note,
                            style: const TextStyle(fontSize: 11.5)),
                        trailing: Text(
                            '${item.available}/${item.totalStock} free',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: item.available == 0
                                    ? AppPalette.red
                                    : AppPalette.amber)),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Close',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppPalette.body)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final rateCtrl = TextEditingController(text: '5.00');
    String category = 'Seating';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Add inventory',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Item name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  items: [
                    for (final c in Catalog.categories.skip(1))
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? category),
                  decoration: const InputDecoration(hintText: 'Category'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: 'Total stock'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            hintText: 'Rate / day (\$)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppPalette.body)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                state.addInventoryItem(
                  name: nameCtrl.text.trim(),
                  category: category,
                  totalStock: int.tryParse(stockCtrl.text) ?? 1,
                  ratePerDay: double.tryParse(rateCtrl.text) ?? 1,
                );
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${nameCtrl.text.trim()} added to inventory'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Add item',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable lifecycle chip: status dot + `label · count`. Selected
/// chips fill with the status wash and read in the status color; idle
/// ones sit on the neutral fill — both resolve through [AppPalette].
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
