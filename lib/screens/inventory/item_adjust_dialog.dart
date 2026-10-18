import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/inventory_item.dart';
import '../../state/workspace_state.dart';
import '../../widgets/chips.dart';
import '../../core/palette.dart';

/// Adjust stock / toggle maintenance for an inventory item.
Future<void> showItemAdjustDialog(
    BuildContext context, InventoryItem item) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (_) => _ItemAdjustDialog(item: item),
  );
}

class _ItemAdjustDialog extends StatefulWidget {
  final InventoryItem item;
  const _ItemAdjustDialog({required this.item});

  @override
  State<_ItemAdjustDialog> createState() => _ItemAdjustDialogState();
}

class _ItemAdjustDialogState extends State<_ItemAdjustDialog> {
  late int _available;
  late bool _maintenance;

  @override
  void initState() {
    super.initState();
    _available = widget.item.available;
    _maintenance = widget.item.maintenance;
  }

  void _save() {
    final state = context.read<WorkspaceState>();
    state.adjustStock(
      widget.item,
      available: _available.clamp(0, widget.item.totalStock),
      maintenance: _maintenance,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item.name} updated'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.name,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.ink)),
                        Text(
                            '${widget.item.category} · ${widget.item.totalStock} total units',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11.5,
                                color: AppPalette.muted)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: widget.item.status.label,
                    fg: widget.item.status.fg,
                    bg: widget.item.status.bg,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Available units',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.ink)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AdjustBtn(
                    icon: Icons.remove_rounded,
                    onTap: _available > 0
                        ? () => setState(() => _available--)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppPalette.fill.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppPalette.stroke),
                      ),
                      child: Text('$_available',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.ink)),
                    ),
                  ),
                  _AdjustBtn(
                    icon: Icons.add_rounded,
                    onTap: _available < widget.item.totalStock
                        ? () => setState(() => _available++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _maintenance = !_maintenance),
                child: Row(
                  children: [
                    Switch(
                      value: _maintenance,
                      activeColor: AppPalette.amber,
                      onChanged: (v) => setState(() => _maintenance = v),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _maintenance
                            ? 'Under maintenance — excluded from Available / On rent until returned to service'
                            : 'Pull this item from availability (repairs, cleaning, damage)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppPalette.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Status now: ${(_maintenance ? ItemStatus.maintenance : widget.item.copyWith(available: _available).status).label}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _maintenance
                        ? AppPalette.amber
                        : AppPalette.body),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                  color: AppPalette.stroke),
                            ),
                            alignment: Alignment.center,
                            child: Text('Cancel',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.body)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: Material(
                        color: AppPalette.primary,
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: _save,
                          child: const Center(
                            child: Text('Save changes',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _AdjustBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.primarySoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 17,
              color:
                  onTap == null ? AppPalette.faint : AppPalette.primary),
        ),
      ),
    );
  }
}
