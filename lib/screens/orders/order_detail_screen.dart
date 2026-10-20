import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_locale.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/customer.dart';
import '../../models/payment_receipt.dart';
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
import '../../models/account.dart';

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
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final days = live.eventDate.difference(DateTime.now()).inDays;

    final customer = state.customerByName(live.customerName);

    final header = SectionCard(
      icon: Icons.receipt_long_outlined,
      title: '${AppLocale.t('Order')} ${live.id}',
      subtitle: AppLocale.tf('Created {n}', {
        'n': Fmt.shortDateTime(live.createdAt),
      }),
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
                  label: AppLocale.t('Event date'),
                  value: Fmt.shortDate(live.eventDate)),
              _MetaFact(
                  icon: Icons.schedule_rounded,
                  label: AppLocale.t('Timeline'),
                  value: AppLocale.relativeDay(days)),
              _MetaFact(
                  icon: Icons.inventory_2_outlined,
                  label: AppLocale.t('Items'),
                  value: Fmt.items(live.itemCount)),
              _MetaFact(
                  icon: Icons.contact_phone_outlined,
                  label: AppLocale.t('Contact'),
                  value: live.contactName),
            ],
          ),
        ],
      ),
    );

    final manifest = SectionCard(
      icon: Icons.list_alt_rounded,
      title: AppLocale.t('Item manifest'),
      child: live.lineItems.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                  AppLocale.t('This order was created without a manifest.'),
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
                      child: Text(
                          '${AppLocale.t('Total')} · ${Fmt.items(live.itemCount)}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppPalette.muted)),
                    ),
                    Text(Fmt.moneySmart(live.total),
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
            title: AppLocale.t('Notes'),
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
      title: AppLocale.t('Customer'),
      child: customer == null
          ? Text(
              AppLocale.tf(
                  '{n} is not in the directory yet — added bookings will link automatically.',
                  {
                    'n': live.customerName
                  }),
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
      eyebrow: '${AppLocale.t('Orders')} / ${live.id}',
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
                    Text(
                        '${Fmt.moneyCents(line.unitPrice)} / ${AppLocale.t('unit')}',
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
                child: Text(Fmt.moneyCents(line.lineTotal),
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
    // The ledger is the derived truth for money; the order document's
    // gate (money flags + ID + signature) decides handover.
    final ledger = state.ledgerFor(order);
    final receipts = state.paymentsForOrder(order.id);
    final ready = order.canHandOver;
    final outstanding = ledger.outstandingTotal;
    final customer = state.customerByName(order.customerName);
    final accent = ready ? AppPalette.green : AppPalette.amber;
    final isOpen = order.status.isOpen;
    final next = ledger.nextDue;

    Future<void> settleNextDue() async {
      final due = next;
      if (due == null) return;
      final method = await pickPaymentMethod(context);
      if (method == null || !context.mounted) return;
      state.recordPayment(order,
          amount: due.amount,
          method: method,
          note: due.bucket.label);
    }

    Future<void> refundCollateral() async {
      final method = await pickPaymentMethod(context);
      if (method == null || !context.mounted) return;
      state.refundCollateral(order, method: method);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ready ? AppPalette.greenBg : AppPalette.amberBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: accent.withOpacity(AppPalette.dark ? 0.3 : 0.22)),
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
                        ? AppLocale.t('Ready for pickup')
                        : AppLocale.t('Settle before pickup'),
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
            // While settling: what is still owed. On a returned order —
            // and once settled — the only number the desk still needs:
            // the collateral in hand. Cents kept when they exist.
            Fmt.moneySmart(
                isOpen && outstanding > kMoneyEps
                    ? outstanding
                    : ledger.collateralHeld),
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
            isOpen && outstanding > kMoneyEps
                ? AppLocale.t('still outstanding on this order')
                : ledger.collateralHeld > kMoneyEps
                    ? AppLocale.t(
                        'fully settled · refund this collateral at return')
                    : AppLocale.t('fully settled · nothing held'),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                color: AppPalette.muted),
          ),
          if (order.lineItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(AppLocale.t('Price by item'),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppPalette.muted)),
            const SizedBox(height: 6),
            for (final line in order.lineItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${line.itemName} ×${line.qty}',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink)),
                        ),
                        Text(Fmt.moneySmart(line.lineTotal),
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.ink)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${AppLocale.t('Down')} ${Fmt.moneySmart(line.downPaymentTotal)} · ${AppLocale.t('Remaining')} ${Fmt.moneySmart(line.remainingTotal)} · ${AppLocale.t('Collateral')} ${Fmt.moneySmart(line.collateralTotal)}',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            color: AppPalette.muted)),
                  ],
                ),
              ),
            const Divider(height: 16),
          ],
          const SizedBox(height: 12),
          // The three money stages, driven by the ledger — partial
          // progress shows paid/target instead of a binary flag.
          for (final bucket in PaymentBucket.values)
            _LedgerRow(
              bucket: bucket,
              target: ledger.targetFor(bucket),
              paid: ledger.paidFor(bucket),
              settled: ledger.bucketSettled(bucket),
              paidAt: switch (bucket) {
                PaymentBucket.downPayment => ledger.downPaidAt,
                PaymentBucket.remaining => ledger.remainingPaidAt,
                PaymentBucket.collateral => ledger.collateralPaidAt,
              },
              method: switch (bucket) {
                PaymentBucket.downPayment => ledger.downMethod,
                PaymentBucket.remaining => ledger.remainingMethod,
                PaymentBucket.collateral => ledger.collateralMethod,
              },
              // Quick action only on the bucket the next receipt fills —
              // later buckets settle THROUGH it (policy order).
              onAction: !isOpen || next == null || bucket != next.bucket
                  ? null
                  : () => settleNextDue(),
            ),
          _CheckRow(
            icon: Icons.badge_outlined,
            label: AppLocale.t('Customer ID verified'),
            done: order.idVerified,
            doneAt: order.idVerifiedAt,
            detail: (customer == null ||
                    (customer.idType.isEmpty && customer.idNumber.isEmpty))
                ? null
                : '· ${customer.idType.isEmpty ? AppLocale.t('ID') : customer.idType}'
                    '${customer.idNumber.isEmpty ? '' : ' · ${customer.idNumber}'}',
            actionLabel: AppLocale.t('Verify ID'),
            onAction: order.idVerifiedAt == null
                ? () => state.markIdVerified(order)
                : null,
          ),
          _SignatureRow(order: order),
          if (isOpen && next != null) ...[
            const SizedBox(height: 10),
            _RecordPaymentButton(order: order, ledger: ledger),
          ],
          // Collateral goes back to the customer once the items return.
          if (order.status == OrderStatus.returned &&
              ledger.collateralHeld > kMoneyEps) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: refundCollateral,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppPalette.green.withOpacity(
                        AppPalette.dark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppPalette.green
                            .withOpacity(AppPalette.dark ? 0.4 : 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.replay_rounded,
                          size: 15, color: AppPalette.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '${AppLocale.t('Refund collateral')} · ${Fmt.moneySmart(ledger.collateralHeld)}',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.green)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // The receipts themselves — the desk's source of truth.
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppPalette.stroke),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.receipt_outlined,
                    size: 13, color: AppPalette.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${AppLocale.t('Receipts')} · ${receipts.length}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppPalette.muted)),
                ),
                Text(
                    '${AppLocale.t('in')} ${Fmt.moneySmart(PaymentLedger.collectedTotal(receipts))}'
                    '${PaymentLedger.refundedTotal(receipts) > kMoneyEps ? ' · ${AppLocale.t('out')} ${Fmt.moneySmart(PaymentLedger.refundedTotal(receipts))}' : ''}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.muted)),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < receipts.length; i++)
              _ReceiptRow(
                receipt: receipts[i],
                showDivider: i < receipts.length - 1,
                canDelete: state.role.canViewReports && isOpen,
                onDelete: () =>
                    _confirmDeleteReceipt(context, state, order, receipts[i]),
              ),
          ],
          if (!ready) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    AppPalette.amber.withOpacity(AppPalette.dark ? 0.14 : 0.10),
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
                    AppLocale.t(
                        'Nothing leaves the shop until every step above is done.'),
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

  void _confirmDeleteReceipt(BuildContext context, WorkspaceState state,
      RentalOrder order, PaymentReceipt receipt) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocale.t('Remove this receipt?'),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink)),
        content: Text(
            '${Fmt.moneySmart(receipt.magnitude)} · ${receipt.method.label}\n\n'
            '${AppLocale.t('The stage flags are re-derived from the receipts that remain — a stage that drops below its target un-settles. This is logged as a correction.')}',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                height: 1.45,
                color: AppPalette.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(AppLocale.t('Cancel'),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: AppPalette.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              state.deletePaymentReceipt(order, receipt);
            },
            child: Text(AppLocale.t('Remove'),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.red)),
          ),
        ],
      ),
    );
  }
}

/// Payment-rail picker — the Ethiopian rails a rental desk actually
/// collects on. Shown BEFORE recording any money so the ledger records
/// HOW it arrived, not just that it did.
Future<PaymentMethod?> pickPaymentMethod(BuildContext context) {
  return showDialog<PaymentMethod>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(AppLocale.t('How was this payment received?'),
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in PaymentMethod.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(dialogCtx).pop(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppPalette.fill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.stroke),
                    ),
                    child: Row(
                      children: [
                        Icon(_methodIcon(m),
                            size: 17, color: AppPalette.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(m.label,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppPalette.faint),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(AppLocale.t('Cancel'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  color: AppPalette.muted)),
        ),
      ],
    ),
  );
}

IconData _methodIcon(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.telebirr => Icons.smartphone_rounded,
      PaymentMethod.cbeBirr => Icons.account_balance_rounded,
      PaymentMethod.mpesa => Icons.phone_android_rounded,
      PaymentMethod.chapa => Icons.public_rounded,
      PaymentMethod.card => Icons.credit_card_rounded,
    };

/// One money stage of the payment plan, driven by the ledger — shows
/// live progress ('400 of 1,200') when partially paid instead of a
/// binary flag. The quick action appears ONLY on the bucket the next
/// receipt fills: later buckets settle through it, in policy order.
class _LedgerRow extends StatelessWidget {
  final PaymentBucket bucket;
  final double target;
  final double paid;
  final bool settled;
  final DateTime? paidAt;
  final PaymentMethod? method;
  final VoidCallback? onAction;

  const _LedgerRow({
    required this.bucket,
    required this.target,
    required this.paid,
    required this.settled,
    required this.paidAt,
    required this.method,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final none = target <= kMoneyEps;
    final partial = !none && !settled && paid > kMoneyEps;
    final outstanding = (target - paid).clamp(0, double.infinity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
              none
                  ? Icons.remove_circle_outline_rounded
                  : settled
                      ? Icons.check_circle_rounded
                      : partial
                          ? Icons.adjust_rounded
                          : Icons.radio_button_unchecked,
              size: 16,
              color: none
                  ? AppPalette.faint
                  : settled
                      ? AppPalette.green
                      : AppPalette.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(bucket.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink)),
                    ),
                    if (settled && method != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppPalette.greenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(method!.chip,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.green)),
                      ),
                    ],
                  ],
                ),
                Text(
                  none
                      ? AppLocale.t('none on this order')
                      : settled
                          ? '${AppLocale.t('received')}'
                              '${paidAt == null ? '' : ' · ${Fmt.shortDateTime(paidAt!)}'}'
                          : partial
                              ? '${Fmt.moneySmart(paid)} ${AppLocale.t('of')} ${Fmt.moneySmart(target)}'
                                  ' · ${Fmt.moneySmart(outstanding)} ${AppLocale.t('to go')}'
                              : Fmt.moneySmart(outstanding),
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
                child: Text(AppLocale.t('Mark received'),
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

/// Opens the record-payment dialog — partial amounts welcome, the
/// ledger allocates them in policy order and shows the split BEFORE
/// anything is recorded.
class _RecordPaymentButton extends StatelessWidget {
  final RentalOrder order;
  final PaymentLedger ledger;

  const _RecordPaymentButton({required this.order, required this.ledger});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () => _showRecordPaymentDialog(context, order, ledger),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.primary.withOpacity(AppPalette.dark ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppPalette.primary
                    .withOpacity(AppPalette.dark ? 0.4 : 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.add_card_rounded,
                  size: 15, color: AppPalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(AppLocale.t('Record payment'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary)),
              ),
              Text(
                  '${AppLocale.t('outstanding')} ${Fmt.moneySmart(ledger.outstandingTotal)}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(
    BuildContext context,
    RentalOrder order,
    PaymentLedger ledger,
  ) async {
    final next = ledger.nextDue;
    final amountCtrl = TextEditingController(
      text: next == null ? '' : _amountText(next.amount),
    );
    final noteCtrl = TextEditingController();
    PaymentMethod method = PaymentMethod.cash;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final amount =
              double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
          final applied = ledger.allocationFor(amount);
          final over = amount > ledger.outstandingTotal + kMoneyEps;
          return AlertDialog(
            backgroundColor: AppPalette.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(
                '${AppLocale.t('Record payment')} · #${order.id}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocale.t('Amount received'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppPalette.muted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialogState(() {}),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink),
                    decoration: InputDecoration(
                      prefixText: '${AppLocale.birr} ',
                      prefixStyle: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.muted),
                      filled: true,
                      fillColor: AppPalette.fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppPalette.stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: over
                                ? AppPalette.red
                                : AppPalette.stroke),
                      ),
                    ),
                  ),
                  if (over)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          '${AppLocale.t('exceeds the outstanding')} ${Fmt.moneySmart(ledger.outstandingTotal)}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.red)),
                    )
                  else if (applied.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocale.t('will be applied to'),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: AppPalette.muted)),
                          const SizedBox(height: 3),
                          for (final e in applied.entries)
                            Text(
                                '· ${e.key.label} ${Fmt.moneySmart(e.value)}',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.body)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(AppLocale.t('Payment rail'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppPalette.muted)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final picked = await pickPaymentMethod(context);
                      if (picked != null) setDialogState(() => method = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppPalette.fill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppPalette.stroke),
                      ),
                      child: Row(
                        children: [
                          Icon(_methodIcon(method),
                              size: 17, color: AppPalette.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(method.label,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.ink)),
                          ),
                          Icon(Icons.expand_more_rounded,
                              size: 16, color: AppPalette.faint),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocale.t('Note'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppPalette.muted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppPalette.ink),
                    decoration: InputDecoration(
                      hintText: AppLocale.t('receipt no., collector…'),
                      hintStyle: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppPalette.faint),
                      filled: true,
                      fillColor: AppPalette.fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppPalette.stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppPalette.stroke),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(AppLocale.t('Cancel'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppPalette.muted)),
              ),
              TextButton(
                onPressed: amount <= kMoneyEps || over
                    ? null
                    : () {
                        Navigator.of(dialogCtx).pop();
                        context.read<WorkspaceState>().recordPayment(
                              order,
                              amount: amount,
                              method: method,
                              note: noteCtrl.text,
                            );
                      },
                child: Text(AppLocale.t('Record'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: amount <= kMoneyEps || over
                            ? AppPalette.faint
                            : AppPalette.primary)),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _amountText(double v) =>
      v == v.roundToDouble() ? v.round().toString() : '$v';
}

/// One immutable receipt row of the ledger — money in or out, how it
/// moved, when, and who recorded it. Owners can remove a receipt as a
/// logged correction.
class _ReceiptRow extends StatelessWidget {
  final PaymentReceipt receipt;
  final bool showDivider;
  final bool canDelete;
  final VoidCallback onDelete;

  const _ReceiptRow({
    required this.receipt,
    required this.showDivider,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final refund = receipt.isRefund;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: refund ? AppPalette.greenBg : AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    refund ? Icons.replay_rounded : _methodIcon(receipt.method),
                    size: 14,
                    color: refund ? AppPalette.green : AppPalette.primary),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                            '${refund ? '−' : '+'}${Fmt.moneySmart(receipt.magnitude)}',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: refund
                                    ? AppPalette.green
                                    : AppPalette.ink)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppPalette.fill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(receipt.method.chip,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.muted)),
                        ),
                        if (receipt.recordedBy.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(receipt.recordedBy,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 10,
                                    color: AppPalette.faint)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${Fmt.shortDateTime(receipt.recordedAt)}'
                      '${receipt.note.isEmpty ? '' : ' · ${receipt.note}'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10.5,
                          color: AppPalette.muted),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 15, color: AppPalette.faint),
                  ),
                ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: AppPalette.stroke),
      ],
    );
  }
}

/// A boolean handover requirement row (ID check).
class _CheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final DateTime? doneAt;
  final String? detail;
  final String actionLabel;
  final VoidCallback? onAction;

  const _CheckRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.doneAt,
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
              size: 16, color: done ? AppPalette.green : AppPalette.amber),
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
                if (done && doneAt != null)
                  Text(Fmt.shortDateTime(doneAt!),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: AppPalette.muted))
                else if (detail != null)
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
  const _SignatureRow({required this.order});

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
                Text(AppLocale.t('Rental agreement signed'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text(
                  done
                      ? AppLocale.tf('signed by {n} · {m}', {
                          'n': order.signedName,
                          'm': Fmt.shortDateTime(order.signedAt!),
                        })
                      : AppLocale.t(
                          "capture the customer's signature on the pad"),
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
                child: Text(AppLocale.t('Capture signature'),
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
      _strokes.any((s) => s.length >= 2) || (_current?.length ?? 0) >= 2;

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
                    child: Text(AppLocale.t('Sign rental agreement'),
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
                  AppLocale.tf(
                      'Order #{n} · {e} — the customer signs to accept the rental terms.',
                      {
                        'n': widget.order.id,
                        'e': widget.order.eventName
                      }),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppPalette.muted)),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: AppLocale.t('Printed name'),
                    hintText: AppLocale.t('Full name')),
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
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(() => _strokes.clear()),
                    child: Text(AppLocale.t('Clear'),
                        style:
                            const TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            _hasInk ? AppPalette.primary : AppPalette.faint),
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
                                      .clamp(0.0, kSignatureGridMax.toDouble()),
                                  (((p.dy - bounds.top) /
                                              (bounds.height == 0
                                                  ? 1
                                                  : bounds.height) *
                                              kSignatureGridMax)
                                          .roundToDouble())
                                      .clamp(0.0, kSignatureGridMax.toDouble()),
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
                    child: Text(AppLocale.t('Save signature'),
                        style:
                            const TextStyle(fontFamily: AppTheme.fontFamily)),
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
                Text(
                    '${customer.company} · ${AppLocale.tr(customer.rentals == 1 ? '1 rental' : '{n} rentals', customer.rentals)}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppPalette.muted),
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
      title: AppLocale.t('Update status'),
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
                      OrderStatus.confirmed => AppLocale.tf(
                          'Payment accepted — {n} marked paid',
                          {'n': order.id}),
                      OrderStatus.returned => AppLocale.tf(
                          '{n} returned — restock items after inspection',
                          {'n': order.id}),
                      OrderStatus.outForDelivery => AppLocale.tf(
                          '{n} handed over — items are with the customer',
                          {'n': order.id}),
                      OrderStatus.preparing =>
                        AppLocale.tf('{n} staged for prep', {'n': order.id}),
                      OrderStatus.needsPayment =>
                        AppLocale.tf('{n} awaiting payment', {'n': order.id}),
                    }),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
          if (next.contains(OrderStatus.outForDelivery) && !order.canHandOver)
            Text(
              AppLocale.t(
                  'Handover blocked — finish the checklist above first.'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppPalette.amber),
            ),
          if (next.isEmpty)
            Text(
                AppLocale.t('This order is fully closed — nothing left to do.'),
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
