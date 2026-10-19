import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../services/csv_export.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../models/customer.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/motion.dart';
import 'customer_detail_screen.dart';
import 'customer_insights_screen.dart';
import '../booking/new_booking_sheet.dart';
import '../../core/palette.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;

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
                child: Text('Customers',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: Density.compact(context) ? 17 : 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppPalette.ink)),
              ),
              PrimaryButton(
                label: 'Add customer',
                icon: Icons.person_add_alt_1_outlined,
                onTap: () => _showAddDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

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
                    icon: Icons.people_outline,
                    iconColor: AppPalette.primary,
                    iconBg: AppPalette.primarySoft,
                    label: 'Total customers',
                    value: '${state.customers.length}',
                    subtitle: 'In your directory',
                    onTap: () => _openInsights(context),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.repeat_rounded,
                    iconColor: AppPalette.purple,
                    iconBg: AppPalette.purpleBg,
                    label: 'Repeat customers',
                    value:
                        '${_repeatPct(state)}%',
                    subtitle: '3+ bookings',
                    onTap: () => _openInsights(context),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppPalette.green,
                    iconBg: AppPalette.greenBg,
                    label: 'Customer value',
                    value: _totalValue(state),
                    subtitle: 'Lifetime spend',
                    onTap: () => _openInsights(context),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.schedule_rounded,
                    iconColor: AppPalette.amber,
                    iconBg: AppPalette.amberBg,
                    label: 'Follow-ups',
                    value: '${state.followUpsCount}',
                    subtitle: 'No booking in 30+ days',
                    onTap: () => _openInsights(context),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          _Directory(state: state),
        ],
      ),
    );
  }

  void _openInsights(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const CustomerInsightsScreen(),
    ));
  }

  String _repeatPct(WorkspaceState state) {
    if (state.customers.isEmpty) return '0';
    final repeat = state.customers.where((c) => c.isRepeat).length;
    return ((repeat / state.customers.length) * 100).round().toString();
  }

  String _totalValue(WorkspaceState state) {
    final total =
        state.customers.fold<double>(0, (s, c) => s + c.lifetimeSpend);
    if (total >= 1000) {
      return '\$${(total / 1000).toStringAsFixed(1)}k';
    }
    return '\$${total.toStringAsFixed(0)}';
  }

  void _showAddDialog(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final idNumberCtrl = TextEditingController();
    String idType = 'National ID';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add customer',
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
                decoration: const InputDecoration(hintText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration:
                    const InputDecoration(hintText: 'Company / event group'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Phone'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: idType,
                isDense: true,
                isExpanded: true,
                items: [
                  for (final t in kCustomerIdTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => idType = v ?? 'National ID',
                decoration: const InputDecoration(
                    labelText: 'ID type (payment policy)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idNumberCtrl,
                decoration: const InputDecoration(
                    hintText: 'ID number / serial on the document'),
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
            style:
                FilledButton.styleFrom(backgroundColor: AppPalette.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              state.addCustomer(
                name: nameCtrl.text.trim(),
                company: companyCtrl.text.trim().isEmpty
                    ? '—'
                    : companyCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty
                    ? '—'
                    : emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? '—'
                    : phoneCtrl.text.trim(),
                idType: idType,
                idNumber: idNumberCtrl.text.trim(),
              );
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('${nameCtrl.text.trim()} added to customers'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Add customer',
                style: TextStyle(fontFamily: AppTheme.fontFamily)),
          ),
        ],
      ),
    );
  }
}

class _Directory extends StatelessWidget {
  final WorkspaceState state;
  const _Directory({required this.state});

  @override
  Widget build(BuildContext context) {
    final customers = state.filteredCustomers;
    final df = DateFormat('MMM d, yyyy');

    return SectionCard(
      icon: Icons.people_outline,
      title: 'Customer directory',
      action: OutlineButton(
        label: 'Export',
        icon: Icons.file_download_outlined,
        onTap: () => showCsvExport(
          context,
          title: 'Customers',
          filename: 'customers.csv',
          header: const [
            'id', 'name', 'company', 'email', 'phone', 'id_type', 'id_number',
            'rentals', 'lifetime_spend', 'last_booking'
          ],
          rows: state.customers
              .map((c) => [
                    c.id,
                    c.name,
                    c.company,
                    c.email,
                    c.phone,
                    c.idType,
                    c.idNumber,
                    '${c.rentals}',
                    c.lifetimeSpend.toStringAsFixed(2),
                    DateFormat('yyyy-MM-dd').format(c.lastBooking),
                  ])
              .toList(),
        ),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: state.setCustomerQuery,
            decoration: InputDecoration(
              hintText: 'Search customers',
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: AppPalette.muted),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${customers.length} customers',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppPalette.muted)),
          ),
          const SizedBox(height: 4),

          // header (wide only) — resolved from the screen width, NOT a
          // LayoutBuilder: this card sits inside an IntrinsicHeight (to
          // stretch beside the pulse panel) and LayoutBuilder cannot
          // answer intrinsic-dimension queries.
          if (MediaQuery.sizeOf(context).width < 1050)
            Column(
              children: [
                for (final cust in customers)
                  _CustomerCardWide(cust: cust),
              ],
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 4,
                          child: Text('CUSTOMER',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                      Expanded(
                          flex: 2,
                          child: Text('RENTALS',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                      Expanded(
                          flex: 3,
                          child: Text('LIFETIME SPEND',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                      Expanded(
                          flex: 3,
                          child: Text('LAST BOOKING',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppPalette.muted))),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                for (final cust in customers)
                  HoverFill(
                    onTap: () => openCustomerDetail(context, cust),
                    radius: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              InitialsAvatar(
                                  initials: cust.initials,
                                  color: cust.avatarColor,
                                  size: 36),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(cust.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontFamily:
                                                AppTheme.fontFamily,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppPalette.ink)),
                                    Text(cust.company,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontFamily:
                                                AppTheme.fontFamily,
                                            fontSize: 11.5,
                                            color: AppPalette.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${cust.rentals} rentals',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  color: AppPalette.body)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                              '\$${NumberFormat('#,##0').format(cust.lifetimeSpend)}',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(df.format(cust.lastBooking),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  color: AppPalette.body)),
                        ),
                        SizedBox(
                          width: 40,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _CustomerActionsMenu(
                                cust: cust),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The ⋯ button on each customer row — real actions: open profile,
/// new booking, copy contact details.
class _CustomerActionsMenu extends StatelessWidget {
  final Customer cust;
  const _CustomerActionsMenu({required this.cust});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Customer actions',
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: AppPalette.stroke),
      ),
      onSelected: (v) {
        switch (v) {
          case 'profile':
            openCustomerDetail(context, cust);
          case 'booking':
            showNewBookingSheet(context, prefillCustomer: cust.name);
          case 'email':
            Clipboard.setData(ClipboardData(text: cust.email));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Email copied — ${cust.email}'),
              behavior: SnackBarBehavior.floating,
            ));
          case 'phone':
            Clipboard.setData(ClipboardData(text: cust.phone));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Phone copied — ${cust.phone}'),
              behavior: SnackBarBehavior.floating,
            ));
        }
      },
      offset: const Offset(0, 8),
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'profile',
            height: 38,
            child: Row(children: [
              Icon(Icons.person_outline_rounded, size: 15),
              SizedBox(width: 8),
              Text('View profile',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily, fontSize: 13)),
            ])),
        PopupMenuItem(
            value: 'booking',
            height: 38,
            child: Row(children: [
              Icon(Icons.add_rounded, size: 15),
              SizedBox(width: 8),
              Text('New booking',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily, fontSize: 13)),
            ])),
        PopupMenuItem(
            value: 'email',
            height: 38,
            child: Row(children: [
              Icon(Icons.copy_rounded, size: 15),
              SizedBox(width: 8),
              Text('Copy email',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily, fontSize: 13)),
            ])),
        PopupMenuItem(
            value: 'phone',
            height: 38,
            child: Row(children: [
              Icon(Icons.copy_all_rounded, size: 15),
              SizedBox(width: 8),
              Text('Copy phone',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily, fontSize: 13)),
            ])),
      ],
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.stroke),
        ),
        child: Icon(Icons.more_horiz, size: 15, color: AppPalette.muted),
      ),
    );
  }
}

class _CustomerCardWide extends StatelessWidget {
  final Customer cust;
  const _CustomerCardWide({required this.cust});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    return HoverFill(
      onTap: () => openCustomerDetail(context, cust),
      radius: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppPalette.stroke)),
        ),
        child: Row(
        children: [
          InitialsAvatar(
              initials: cust.initials,
              color: cust.avatarColor,
              size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cust.name,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text(cust.company,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${NumberFormat('#,##0').format(cust.lifetimeSpend)}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink)),
              const SizedBox(height: 2),
              Text(
                  '${cust.rentals} rentals · ${df.format(cust.lastBooking)}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppPalette.muted)),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: AppPalette.faint),
        ],
      ),
      ),
    );
  }
}
