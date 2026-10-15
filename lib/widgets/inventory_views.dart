import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/inventory_item.dart';
import 'chips.dart';
import 'cards.dart';
import 'indicators.dart';

/// Column headers of the inventory table.
class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: AppColors.textMuted,
      ),
    );
  }
}

/// Wide-layout inventory table (dashboard snapshot & inventory screen).
class InventoryTable extends StatelessWidget {
  final List<InventoryItem> items;
  final void Function(InventoryItem item) onRent;
  final void Function(InventoryItem item) onEdit;
  final bool showActions;
  final bool compactMode;

  const InventoryTable({
    super.key,
    required this.items,
    required this.onRent,
    required this.onEdit,
    this.showActions = true,
    this.compactMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          child: Row(
            children: [
              Expanded(flex: compactMode ? 5 : 4, child: const _HeaderCell('Item name')),
              const Expanded(flex: 2, child: _HeaderCell('Category')),
              const Expanded(flex: 2, child: _HeaderCell('Total stock')),
              Expanded(
                  flex: compactMode ? 3 : 2, child: const _HeaderCell('Available')),
              if (!compactMode) const Expanded(flex: 2, child: _HeaderCell('Status')),
              if (showActions) const SizedBox(width: 128),
            ],
          ),
        ),
        for (final item in items)
          _InventoryRow(
            item: item,
            onRent: () => onRent(item),
            onEdit: () => onEdit(item),
            showActions: showActions,
            compactMode: compactMode,
          ),
      ],
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onRent;
  final VoidCallback onEdit;
  final bool showActions;
  final bool compactMode;

  const _InventoryRow({
    required this.item,
    required this.onRent,
    required this.onEdit,
    required this.showActions,
    required this.compactMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: compactMode ? 5 : 4,
            child: Row(
              children: [
                IconChipLite(
                  icon: item.icon,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          )),
                      const SizedBox(height: 1),
                      Text(item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(item.category,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: AppColors.textBody,
                )),
          ),
          Expanded(
            flex: 2,
            child: Text('${item.totalStock}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                )),
          ),
          Expanded(
            flex: compactMode ? 3 : 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${item.available}',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      )),
                  Text(' / ${item.totalStock}',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textFaint,
                      )),
                  const SizedBox(width: 8),
                  AvailabilityBar(
                      fraction: item.availabilityFraction, width: 46),
                ],
              ),
            ),
          ),
          if (!compactMode)
            Expanded(
              flex: 2,
              child: StatusBadge(
                label: item.status.label,
                fg: item.status.fg,
                bg: item.status.bg,
              ),
            ),
          if (showActions)
            SizedBox(
              width: 148,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: onRent,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded,
                                size: 15, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Rent',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: onEdit,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            size: 15, color: AppColors.textBody),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact stacked list card (tablet-768 / mobile inventory).
class InventoryListTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  const InventoryListTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Row(
            children: [
              IconChipLite(
                icon: item.icon,
                color: AppColors.primary,
                bg: AppColors.primarySoft,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      '${item.available} of ${item.totalStock} available',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(
                label: item.status.label,
                fg: item.status.fg,
                bg: item.status.bg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
