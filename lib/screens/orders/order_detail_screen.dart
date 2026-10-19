import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/customer.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_status_style.dart';
import '../customers/customer_detail_screen.dart';
import '../../core/palette.dart';
import '../../data/appwrite_mappers.dart';

/// Full order detail — opened by tapping any order row/card, task or
/// pickup run. Shows the quoted manifest, booking notes, the v1.26
/// payment ledger (down payment → remaining → collateral → ID →
/// signature) and the status flow with real actions.
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

    final days = live.eventDate
        .difference(DateTime.now())
        .inDays;

    final customer = state.customerByName(live.customerName);

    final header = SectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Order ${live.id}',
      subtitle: 'Created ${df.format(live.createdAt)}',
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
                  value: days > 1
                      ? 'In $days days'
                      : days == 1
                          ? 'Tomorrow'
                          : days == 0
                              ? 'Today'
                              : -days == 1
                                  ? 'Yesterday'
                                  : '${-days} days ago'),
              _MetaFact(
                  icon: Icons.inventory_2_outlined,
                  label: 'Items',
                  value: '${live.itemCount} items'),
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

    final notesCard = live.notes.isEmpty
        ? null // no notes → no card: the section only earns its place
                   // when there is something to read
        : SectionCard(
            icon: Icons.sticky_note_2_outlined,
            title: 'Notes',
            child: Text(
              live.notes,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  height: 1.5,
                  color: AppPalette.body),
            ),
          );

    final payment = _PaymentsHandoverCard(order: live);

    final customerCard = SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Customer',
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
                      if (notesCard != null) ...[
                        const SizedBox(height: 14),
                        notesCard,
                      ],
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
          if (notesCard != null) ...[
            const SizedBox(height: 14),
            notesCard,
          ],
          const SizedBox(height: 14),
          customerCard,
          const SizedBox(height: 14),
          actions,
        ],
      ],
    );

    return DetailPage(
      eyebrow: 'Orders / ${live.id}',
      title: live.eventName,
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

class _PaymentsHandoverCard extends StatelessWidget {
  final RentalOrder order;
  const _PaymentsHandoverCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final df = DateFormat('MMM d, HH:mm');
    final ready = order.canHandOver;
    final outstanding = order.outstandingTotal;
    final customer = state.customerByName(order.customerName);
    final accent = ready ? AppPalette.green : AppPalette.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ready ? AppPalette.greenBg : AppPalette.amberBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: accent.withOpacity(AppPalette.dark ? 0.3 : 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  ready
                      ? Icons.verified_rounded
                      : Icons.account_balance_wallet_outlined,
                  size: 17,
                  color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    ready
                        ? 'Ready for pickup'
                        : 'Settle before pickup',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            outstanding > 0
                ? money.format(outstanding)
                : money.format(order.total),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 26,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppPalette.ink),
          ),
          const SizedBox(height: 2),
          Text(
            outstanding > 0
                ? 'still outstanding on this order'
                : 'fully settled · refund collateral at return',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                color: AppPalette.muted),
          ),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Down payment',
            amount: order.downPayment,
            paid: order.downPaymentPaid,
            paidAt: order.downPaymentPaidAt,
            df: df,
            actionLabel: 'Mark received',
            onAction: order.downPayment > 0 && order.downPaymentPaidAt == null
                ? () => state.markDownPaymentReceived(order)
                : null,
          ),
          _PaymentRow(
            label: 'Remaining balance',
            amount: order.remainingDue,
            paid: order.remainingPaid,
            paidAt: order.remainingPaidAt,
            df: df,
            actionLabel: 'Mark received',
            onAction: order.remainingDue > 0 && order.remainingPaidAt == null
                ? () => state.markRemainingReceived(order)
                : null,
          ),
          _PaymentRow(
            label: 'Collateral (refundable)',
            amount: order.collateralAmount,
            paid: order.collateralPaid,
            paidAt: order.collateralPaidAt,
            df: df,
            actionLabel: 'Mark held',
            onAction:
                order.collateralAmount > 0 && order.collateralPaidAt == null
                    ? () => state.markCollateralReceived(order)
                    : null,
          ),
          _CheckRow(
            icon: Icons.badge_outlined,
            label: 'Customer ID verified',
            done: order.idVerified,
            doneAt: order.idVerifiedAt,
            df: df,
            detail: (customer == null ||
                    (customer.idType.isEmpty && customer.idNumber.isEmpty))
                ? null
                : '· ${customer.idType.isEmpty ? 'ID' : customer.idType}'
                    '${customer.idNumber.isEmpty ? '' : ' · ${customer.idNumber}'}',
            actionLabel: 'Verify ID',
            onAction:
                order.idVerifiedAt == null ? () => state.markIdVerified(order) : null,
          ),
          _SignatureRow(order: order, df: df),
          if (!ready) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.amber.withOpacity(AppPalette.dark ? 0.14 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in order.handoverBlockers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.priority_high_rounded,
                              size: 12, color: AppPalette.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(b,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.body)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Nothing leaves the shop until every step above is done.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppPalette.muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One settled/unsettled money line of the payment plan.
class _PaymentRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool paid;
  final DateTime? paidAt;
  final DateFormat df;
  final String actionLabel;
  final VoidCallback? onAction;

  const _PaymentRow({
    required this.label,
    required this.amount,
    required this.paid,
    required this.paidAt,
    required this.df,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
              amount <= 0
                  ? Icons.remove_circle_outline_rounded
                  : paid
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
              size: 16,
              color: amount <= 0
                  ? AppPalette.faint
                  : paid
                      ? AppPalette.green
                      : AppPalette.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text(
                  amount <= 0
                      ? 'none on this order'
                      : paid
                          ? 'received '
                              '· ${paidAt == null ? '' : df.format(paidAt!)}'
                          : money.format(amount),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppPalette.muted),
                ),
              ],
            ),
          ),
          if (onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(actionLabel,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A boolean handover requirement row (ID check).
class _CheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final DateTime? doneAt;
  final DateFormat df;
  final String? detail;
  final String actionLabel;
  final VoidCallback? onAction;

  const _CheckRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.doneAt,
    required this.df,
    required this.actionLabel,
    required this.onAction,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : icon,
              size: 16,
              color: done ? AppPalette.green : AppPalette.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                if (detail != null)
                  Text(detail!,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: AppPalette.muted)),
              ],
            ),
          ),
          if (onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(actionLabel,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Signature requirement row — opens the capture pad, shows the stored
/// signature once the agreement is signed.
class _SignatureRow extends StatelessWidget {
  final RentalOrder order;
  final DateFormat df;
  const _SignatureRow({required this.order, required this.df});

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final done = order.signatureCaptured;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.draw_outlined,
              size: 16, color: done ? AppPalette.green : AppPalette.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rental agreement signed',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text(
                  done
                      ? 'signed by ${order.signedName} · ${df.format(order.signedAt!)}'
                      : "capture the customer's signature on the pad",
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppPalette.muted),
                ),
              ],
            ),
          ),
          if (done)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.stroke),
              ),
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: 84,
                height: 34,
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: signatureFromDoc(order.signatureData),
                    color: const Color(0xFF1A1D2E),
                    stroke: 2.2,
                    gridMax: kSignatureGridMax,
                  ),
                ),
              ),
            )
          else
            InkWell(
              onTap: () async {
                final result = await showSignaturePadDialog(context, order);
                if (result == null) return;
                state.saveSignature(order,
                    strokes: result.strokes, signedName: result.signedName);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Capture signature',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Result of the signature pad.
class SignatureCapture {
  final List<List<Offset>> strokes; // normalized to 0..kSignatureGridMax
  final String signedName;
  const SignatureCapture({required this.strokes, required this.signedName});
}

Future<SignatureCapture?> showSignaturePadDialog(
        BuildContext context, RentalOrder order) =>
    showDialog<SignatureCapture>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _SignaturePadDialog(order: order),
    );

class _SignaturePadDialog extends StatefulWidget {
  final RentalOrder order;
  const _SignaturePadDialog({required this.order});

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.order.customerName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _hasInk =>
      _strokes.any((s) => s.length >= 2) ||
      (_current?.length ?? 0) >= 2;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.draw_outlined,
                      size: 18, color: AppPalette.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('Sign rental agreement',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink)),
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
              const SizedBox(height: 4),
              Text(
                  'Order #${widget.order.id} · ${widget.order.eventName} — '
                  'the customer signs to accept the rental terms.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppPalette.muted)),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Printed name', hintText: 'Full name'),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.stroke),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Listener(
                    onPointerDown: (e) =>
                        setState(() => _current = [e.localPosition]),
                    onPointerMove: (e) => setState(() {
                      final c = _current;
                      if (c == null) return;
                      // Decimate: skip points too close to the last one.
                      final last = c.last;
                      if ((e.localPosition - last).distance < 3) return;
                      c.add(e.localPosition);
                    }),
                    onPointerUp: (e) => setState(() {
                      final c = _current;
                      if (c != null && c.length >= 2) _strokes.add(c);
                      _current = null;
                    }),
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: [
                          ..._strokes,
                          if (_current != null) _current!,
                        ],
                        color: const Color(0xFF1A1D2E),
                        stroke: 2.6,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed:
                        _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
                    child: const Text('Clear',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _hasInk
                            ? AppPalette.primary
                            : AppPalette.faint),
                    onPressed: _hasInk
                        ? () {
                            // Normalize from the strokes' own bounds so
                            // the codec is pad-geometry independent.
                            final all = [
                              for (final s in _strokes) ...s,
                            ];
                            final bounds = all.fold<Rect?>(
                              null,
                              (r, p) => r == null
                                  ? Rect.fromPoints(p, p)
                                  : r.expandToInclude(Rect.fromPoints(p, p)),
                            )!;
                            Offset norm(Offset p) => Offset(
                                  (((p.dx - bounds.left) /
                                              (bounds.width == 0
                                                  ? 1
                                                  : bounds.width) *
                                          kSignatureGridMax)
                                      .roundToDouble())
                                      .clamp(0.0,
                                          kSignatureGridMax.toDouble()),
                                  (((p.dy - bounds.top) /
                                              (bounds.height == 0
                                                  ? 1
                                                  : bounds.height) *
                                          kSignatureGridMax)
                                      .roundToDouble())
                                      .clamp(0.0,
                                          kSignatureGridMax.toDouble()),
                                );
                            final scaled = _strokes
                                .map((s) => s.map(norm).toList())
                                .toList(growable: false);
                            Navigator.pop(
                              context,
                              SignatureCapture(
                                strokes: scaled,
                                signedName: _nameCtrl.text,
                              ),
                            );
                          }
                        : null,
                    child: const Text('Save signature',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
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

/// Paints signature strokes. Coordinates are either raw local pixels
/// (when [gridMax] is null) or normalized 0..[gridMax] (documents).
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double stroke;
  final int? gridMax;

  const _SignaturePainter({
    required this.strokes,
    required this.color,
    required this.stroke,
    this.gridMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path();
      for (var i = 0; i < s.length; i++) {
        final p = gridMax == null
            ? s[i]
            : Offset(
                s[i].dx / gridMax! * size.width,
                s[i].dy / gridMax! * size.height,
              );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) =>
      old.strokes != strokes || old.color != color;
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
/// and lands in the activity log. The offered transitions come from
/// [kOrderTransitions]; the state layer independently enforces them.
class _StatusActionsCard extends StatelessWidget {
  final RentalOrder order;
  const _StatusActionsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final next = kOrderTransitions[order.status] ?? const <OrderStatus>[];

    return SectionCard(
      icon: Icons.bolt_rounded,
      title: 'Update status',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in next)
            OutlineButton(
              label: s.actionLabel,
              icon: _statusIcon(s),
              fg: s.fg,
              onTap: () {
                final ok = state.updateOrderStatus(order, s);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(switch (s) {
                      OrderStatus.confirmed =>
                        'Payment accepted — ${order.id} marked paid',
                      OrderStatus.returned =>
                        '${order.id} returned — restock items after inspection',
                      OrderStatus.outForDelivery =>
                        '${order.id} handed over — items are with the customer',
                      OrderStatus.preparing =>
                        '${order.id} staged for prep',
                      OrderStatus.needsPayment =>
                        '${order.id} awaiting payment',
                    }),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
          if (next.contains(OrderStatus.outForDelivery) &&
              !order.canHandOver)
            Text(
              'Handover blocked — finish the checklist above first.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppPalette.amber),
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

  IconData _statusIcon(OrderStatus s) => switch (s) {
        OrderStatus.confirmed => Icons.payments_outlined, // accept payment
        OrderStatus.preparing => Icons.inventory_2_outlined, // stage & pack
        OrderStatus.outForDelivery => Icons.shopping_bag_outlined, // pickup
        OrderStatus.needsPayment => Icons.request_quote_outlined,
        OrderStatus.returned => Icons.assignment_return_outlined,
      };
}

/// KPI card reused by the orders screen to jump here.
void openOrderDetail(BuildContext context, RentalOrder order) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => OrderDetailScreen(order: order),
  ));
}
