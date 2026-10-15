import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../models/customer.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/indicators.dart';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconChipLite(
                  icon: Icons.people_outline,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Workspace / Customers'),
                    const SizedBox(height: 4),
                    Text('Customers',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: Density.compact(context) ? 17 : 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppColors.textDark)),
                  ],
                ),
              ),
              PrimaryButton(
                label: 'Add customer',
                icon: Icons.person_add_alt_1_outlined,
                onTap: () => _showAddDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Keep relationships warm and repeat bookings moving.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppColors.textMuted)),
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
                  child: const KpiCard(
                    icon: Icons.people_outline,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: 'Total customers',
                    value: '${Seed.totalCustomersKpi}',
                    subtitle: 'This quarter',
                    trailing: TrendChip(
                        text: '+12', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.repeat_rounded,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Repeat customers',
                    value: '68%',
                    subtitle: 'Healthy retention',
                    trailing: TrendChip(
                        text: '+8.4%', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.green,
                    iconBg: AppColors.greenBg,
                    label: 'Customer value',
                    value: '\$42.8k',
                    subtitle: 'Year to date',
                    trailing: TrendChip(
                        text: '14.2%', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Follow-ups',
                    value: '${Seed.followUps}',
                    subtitle: 'Keep the loop tight',
                    trailing: TrendChip(
                        text: 'Due today', positive: false),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          // directory + pulse
          IntrinsicHeight(
            child: width >= 1050
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: _Directory(state: state)),
                      const SizedBox(width: 14),
                      const Expanded(flex: 4, child: _PulsePanel()),
                    ],
                  )
                : Column(
                    children: [
                      _Directory(state: state),
                      const SizedBox(height: 14),
                      const _PulsePanel(),
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
    final companyCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppColors.textBody)),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
      subtitle: 'Your most active rental relationships.',
      action: OutlineButton(
        label: 'Export',
        icon: Icons.file_download_outlined,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer list exported (demo)'),
            behavior: SnackBarBehavior.floating,
          ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: state.setCustomerQuery,
            decoration: const InputDecoration(
              hintText: 'Search customers',
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
              prefixIconConstraints: BoxConstraints(minWidth: 42),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${customers.length} customers',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppColors.textMuted)),
          ),
          const SizedBox(height: 4),

          // header (wide only)
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 560;
            if (!wide) {
              return Column(
                children: [
                  for (final cust in customers)
                    _CustomerCardWide(cust: cust),
                ],
              );
            }
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12, left: 4, right: 4),
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
                                  color: AppColors.textMuted))),
                      Expanded(
                          flex: 2,
                          child: Text('RENTALS',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.textMuted))),
                      Expanded(
                          flex: 3,
                          child: Text('LIFETIME SPEND',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.textMuted))),
                      Expanded(
                          flex: 3,
                          child: Text('LAST BOOKING',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.textMuted))),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                for (final cust in customers)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.cardBorder)),
                    ),
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
                                        style: const TextStyle(
                                            fontFamily:
                                                AppTheme.fontFamily,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark)),
                                    Text(cust.company,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily:
                                                AppTheme.fontFamily,
                                            fontSize: 11.5,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${cust.rentals} rentals',
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  color: AppColors.textBody)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                              '\$${NumberFormat('#,##0').format(cust.lifetimeSpend)}',
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(df.format(cust.lastBooking),
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  color: AppColors.textBody)),
                        ),
                        SizedBox(
                          width: 40,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.cardBorder),
                              ),
                              child: const Icon(Icons.more_horiz,
                                  size: 15, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
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
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                Text(cust.company,
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${NumberFormat('#,##0').format(cust.lifetimeSpend)}',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(
                  '${cust.rentals} rentals · ${df.format(cust.lastBooking)}',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Purple "Relationship pulse" insight panel.
class _PulsePanel extends StatelessWidget {
  const _PulsePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FE),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFE5DFFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Relationship pulse',
              color: Color(0xFF8B5CF6)),
          const SizedBox(height: 10),
          const Text('Customers are booking earlier.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textDark)),
          const SizedBox(height: 10),
          const Text(
            'Average lead time is up to 23 days, giving the team more room to prep and upsell.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              height: 1.55,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+18%',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: Density.compact(context) ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: const Color(0xFF7C3AED))),
              const SizedBox(width: 9),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('average lead time',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 46,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in [10.0, 12.0, 15.0, 13.0, 18.0, 24.0, 30.0, 38.0, 46.0])
                  Expanded(
                    child: Container(
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            const Color(0xFFB7ADF4),
                            const Color(0xFF8B78EC).withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Text('View customer insights',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED))),
              SizedBox(width: 5),
              Icon(Icons.north_east_rounded,
                  size: 14, color: Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }
}
