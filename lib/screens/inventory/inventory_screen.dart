import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/inventory_views.dart';
import '../../widgets/kpi_card.dart';
import '../booking/new_booking_sheet.dart';
import 'item_adjust_dialog.dart';
import '../../widgets/filters.dart';
import '../../widgets/indicators.dart';
import '../../core/palette.dart';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChipLite(
                  icon: Icons.inventory_2_outlined,
                  color: AppPalette.primary,
                  bg: AppPalette.primarySoft,
                  size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Workspace / Inventory'),
                    const SizedBox(height: 4),
                    Text('Inventory',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: Density.compact(context) ? 17 : 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppPalette.ink)),
                  ],
                ),
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
          const SizedBox(height: 6),
          Text('Track every piece of equipment from shelf to event site.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppPalette.muted)),
          const SizedBox(height: 14),

          // KPI grid
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
                    value: '${Seed.inventoryTotal}',
                    subtitle: 'Across 6 categories',
                    trailing: const TrendChip(text: '+24', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppPalette.green,
                    iconBg: AppPalette.greenBg,
                    label: 'Available now',
                    value: '${Seed.inventoryAvailable}',
                    subtitle: 'Of total inventory',
                    trailing: TrendChip(
                        text: '${availablePct.toStringAsFixed(0)}%',
                        positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppPalette.amber,
                    iconBg: AppPalette.amberBg,
                    label: 'On rent',
                    value: '${Seed.inventoryOnRent}',
                    subtitle: 'Across 24 bookings',
                    trailing: TrendChip(
                        text: '${onRentPct.toStringAsFixed(1)}%',
                        positive: false),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.build_circle_outlined,
                    iconColor: AppPalette.blue,
                    iconBg: AppPalette.blueBg,
                    label: 'Needs attention',
                    value: '${Seed.inventoryAttention}',
                    subtitle: 'Maintenance queue',
                    trailing: const TrendChip(
                        text: '${Seed.attentionDelta} items',
                        positive: false),
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
            subtitle: 'Availability updates live as bookings are created and returned.',
            action: OutlineButton(
              label: 'Export CSV',
              icon: Icons.file_download_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Inventory exported as CSV (demo)'),
                  behavior: SnackBarBehavior.floating,
                ),
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
                      items: Seed.categories,
                      onChanged: state.setCategoryFilter,
                    ),
                  ],
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
                    for (final c in Seed.categories.skip(1))
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
