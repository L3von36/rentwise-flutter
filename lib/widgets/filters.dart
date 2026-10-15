import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';

/// "View inventory ↗" style link chip.
class LinkChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const LinkChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )),
              const SizedBox(width: 4),
              const Icon(Icons.north_east_rounded,
                  size: 13, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown filter pill ("All categories ⌄").
class PopupFilterButton extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const PopupFilterButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      offset: const Offset(0, 8),
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(
            value: item,
            height: 34,
            child: Row(
              children: [
                if (item == value)
                  const Icon(Icons.check_rounded,
                      size: 15, color: AppColors.primary)
                else
                  const SizedBox(width: 15),
                const SizedBox(width: 6),
                Text(item,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight:
                          item == value ? FontWeight.w700 : FontWeight.w500,
                      color: item == value
                          ? AppColors.primary
                          : AppColors.textBody,
                    )),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_rounded,
                size: 15, color: AppColors.textMuted),
            const SizedBox(width: 7),
            Text(value,
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody)),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 15, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
