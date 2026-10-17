import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/inventory_item.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../core/palette.dart';

/// Booking line with quantity stepper.
class _LineRow extends StatelessWidget {
  final BookingLine line;
  final VoidCallback onRemove;
  final ValueChanged<int> onQty;
  const _LineRow({
    required this.line,
    required this.onRemove,
    required this.onQty,
  });

  @override
  Widget build(BuildContext context) {
    final item = line.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.fill.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: Row(
        children: [
          IconChipLite(
              icon: item.icon,
              color: AppPalette.primary,
              bg: AppPalette.primarySoft,
              size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(
                    '${line.qty} × \$${item.ratePerDay.toStringAsFixed(2)}/day · ${item.available} available',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          _QtyStepper(
            qty: line.qty,
            max: item.available,
            onChanged: onQty,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppPalette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.qty, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.raise,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: Row(
        children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            onTap: qty > 1 ? () => onChanged(qty - 1) : null,
          ),
          SizedBox(
            width: 30,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink)),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            onTap: qty < max ? () => onChanged(qty + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon,
            size: 14,
            color: onTap == null ? AppPalette.faint : AppPalette.body),
      ),
    );
  }
}

/// New rental booking — centered dialog on wide, bottom sheet on compact.
Future<void> showNewBookingSheet(BuildContext context,
    {InventoryItem? prefill}) {
  final wide = MediaQuery.sizeOf(context).width >= 640;
  if (wide) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _BookingDialog(prefill: prefill),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      // Sit above the keyboard AND the system nav bar (whichever is taller)
      // — the sheet itself draws edge-to-edge behind system UI.
      padding: EdgeInsets.only(
        bottom: math.max(MediaQuery.viewInsetsOf(context).bottom,
            MediaQuery.paddingOf(context).bottom),
      ),
      child: _BookingDialog(embed: true, prefill: prefill),
    ),
  );
}

class _BookingDialog extends StatefulWidget {
  final bool embed;
  final InventoryItem? prefill;
  const _BookingDialog({this.embed = false, this.prefill});

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  String? _customer;
  final _eventCtrl = TextEditingController();
  DateTime? _eventDate;
  String? _notes;
  InventoryItem? _picker;
  final List<BookingLine> _lines = [];

  double get _total => _lines.fold(0, (s, l) => s + l.qty * l.item.ratePerDay);
  bool get _valid =>
      _customer != null &&
      _eventCtrl.text.trim().isNotEmpty &&
      _eventDate != null &&
      _lines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<WorkspaceState>();
      setState(() {
        _customer ??=
            state.customers.isNotEmpty ? state.customers.first.name : null;
        _picker ??=
            state.inventory.isNotEmpty ? state.inventory.first : null;
        final pre = widget.prefill;
        if (pre != null) {
          _addLine(pre);
        }
      });
    });
  }

  void _addLine(InventoryItem item) {
    final existing = _lines.indexWhere((l) => l.item.id == item.id);
    if (existing != -1) {
      if (_lines[existing].qty < item.available) _lines[existing].qty++;
    } else if (item.available > 0) {
      _lines.add(BookingLine(item: item, qty: 1));
    }
  }

  void _submit() {
    final state = context.read<WorkspaceState>();
    final id = state.createBooking(
      customerName: _customer!,
      eventName: _eventCtrl.text.trim(),
      eventDate: _eventDate!,
      lines: List.of(_lines),
      notes: _notes,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking #$id created · $_customer confirmed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final wide = MediaQuery.sizeOf(context).width >= 640;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header
        Row(
          children: [
            IconChipLite(
                icon: Icons.post_add_rounded,
                color: AppPalette.primary,
                bg: AppPalette.primarySoft,
                size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New rental booking',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.ink)),
                  const SizedBox(height: 2),
                  Text('Reserve items for an upcoming event.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppPalette.muted)),
                ],
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 18, color: AppPalette.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // customer + event
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _Label('Customer'),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: _Label('Event name'),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: _customer,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          for (final c in state.customers)
                            DropdownMenuItem(
                                value: c.name,
                                child: Text(c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13))),
                        ],
                        onChanged: (v) => setState(() => _customer = v),
                        decoration: const InputDecoration(
                            hintText: 'Select customer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _eventCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: 'e.g. Foundry Dinner'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const _Label('Event date'),
                const SizedBox(height: 7),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? now.add(const Duration(days: 3)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppPalette.raise,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.stroke),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 17, color: AppPalette.muted),
                        const SizedBox(width: 9),
                        Text(
                          _eventDate == null
                              ? 'Pick a date'
                              : _fmtDate(_eventDate!),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _eventDate == null
                                ? AppPalette.muted
                                : AppPalette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // items
                const _Label('Items'),
                const SizedBox(height: 7),
                if (_lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppPalette.fill.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppPalette.stroke),
                    ),
                    child: Center(
                      child: Text(
                          'No items yet — add the pieces this event needs.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              color: AppPalette.muted)),
                    ),
                  )
                else
                  for (final line in _lines.toList())
                    _LineRow(
                      line: line,
                      onRemove: () =>
                          setState(() => _lines.remove(line)),
                      onQty: (q) => setState(() => line.qty = q),
                    ),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<InventoryItem>(
                        value: _picker,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          for (final i in state.inventory)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                '${i.name} · ${i.available} free',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _picker = v),
                        decoration: const InputDecoration(
                            hintText: 'Choose an item'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _picker == null
                            ? null
                            : () => setState(() {
                                  _addLine(_picker!);
                                }),
                        child: Container(
                          height: 44,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 16, color: AppPalette.primary),
                              const SizedBox(width: 5),
                              Text('Add',
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const _Label('Notes (optional)'),
                const SizedBox(height: 7),
                TextField(
                  maxLines: 2,
                  onChanged: (v) => _notes = v,
                  decoration: const InputDecoration(
                      hintText: 'Delivery instructions, venue contact…'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // footer
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppPalette.stroke)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated total',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            color: AppPalette.muted)),
                    const SizedBox(height: 2),
                    Text('\$${_total.toStringAsFixed(2)} / day',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                  color: _valid ? AppPalette.primary : AppPalette.faint,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: _valid ? _submit : null,
                    child: Container(
                      height: 46,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 17, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Create booking',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (widget.embed || !wide) {
      return Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: content,
      );
    }

    return Dialog(
      backgroundColor: AppPalette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: content,
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppPalette.ink,
        ));
  }
}
