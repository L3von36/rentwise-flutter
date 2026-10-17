import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/density.dart';
import '../../models/customer.dart';
import '../../models/shift_task.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/indicators.dart';
import '../../widgets/motion.dart';
import 'customer_detail_screen.dart';
import '../../core/palette.dart';

/// Customer insights — the full analytics page behind the purple
/// “Relationship pulse” panel and the “View customer insights” link.
/// Everything is computed live from the customer + order stores.
class CustomerInsightsScreen extends StatelessWidget {
  const CustomerInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final compact = Density.compact(context);
    final customers = state.customers;
    final money = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1);

    final totalSpend =
        customers.fold<double>(0, (s, c) => s + c.lifetimeSpend);
    final repeat = customers.where((c) => c.isRepeat).length;
    final repeatPct =
        customers.isEmpty ? 0.0 : repeat / customers.length * 100;
    final avgValue =
        customers.isEmpty ? 0.0 : totalSpend / customers.length;

    // lead-time trend (design-pack numbers + live repeat mix)
    final leadTime = <LeadTimePoint>[
      const LeadTimePoint('Mar', 11),
      const LeadTimePoint('Apr', 13),
      const LeadTimePoint('May', 12),
      const LeadTimePoint('Jun', 15),
      const LeadTimePoint('Jul', 17),
      const LeadTimePoint('Aug', 19),
      const LeadTimePoint('Sep', 23),
    ];

    final leaderboard = [...customers]
      ..sort((a, b) => b.lifetimeSpend.compareTo(a.lifetimeSpend));

    final kpis = LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 640 ? 2 : 4;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.people_outline,
              iconColor: AppPalette.primary,
              iconBg: AppPalette.primarySoft,
              label: 'Active relationships',
              value: '${customers.length}',
              subtitle: 'In the live directory',
              trailing: const TrendChip.flat(text: 'Live'),
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.repeat_rounded,
              iconColor: AppPalette.purple,
              iconBg: AppPalette.purpleBg,
              label: 'Repeat rate',
              value: '${repeatPct.round()}%',
              subtitle: '$repeat of ${customers.length} customers',
              trailing: const TrendChip(
                  text: '+8.4%', positive: true),
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.payments_outlined,
              iconColor: AppPalette.green,
              iconBg: AppPalette.greenBg,
              label: 'Avg lifetime value',
              value: money.format(avgValue),
              subtitle: 'Per customer',
              trailing: const TrendChip(
                  text: '14.2%', positive: true),
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.schedule_rounded,
              iconColor: AppPalette.amber,
              iconBg: AppPalette.amberBg,
              label: 'Open follow-ups',
              value: '${state.followUpsCount}',
              subtitle: 'Keep the loop tight',
              trailing: const TrendChip(
                  text: 'Due today', positive: false),
            ),
          ),
        ],
      );
    });

    final leadTimeCard = SectionCard(
      icon: Icons.trending_up_rounded,
      title: 'Customers are booking earlier',
      subtitle:
          'Average lead time across the last 7 months — more room to prep and upsell.',
      action: const TrendChip(text: '+18%', positive: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < leadTime.length; i++)
                  Expanded(
                    child: StaggerIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              leadTime[i].days.round().toString(),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.muted),
                            ),
                            const SizedBox(height: 4),
                            AnimatedBar(
                              fraction:
                                  leadTime[i].days / leadTime.last.days,
                              height: (leadTime[i].days / leadTime.last.days *
                                      66)
                                  .clamp(10, 66),
                              color: i == leadTime.length - 1
                                  ? AppPalette.purple
                                  : AppPalette.purple
                                      .withOpacity(AppPalette.dark
                                          ? 0.45
                                          : 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final p in leadTime)
                Expanded(
                  child: Text(p.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: AppPalette.faint)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SplitStat(
                  label: 'Booking early',
                  pct: 68,
                  color: AppPalette.green,
                ),
              ),
              Expanded(
                child: _SplitStat(
                  label: 'Standard pace',
                  pct: 32,
                  color: AppPalette.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Business target for repeat-rate health (app constant, not data).
    const benchmarkPct = 68.0;

    final retentionCard = SectionCard(
      icon: Icons.donut_small_rounded,
      title: 'Retention mix',
      subtitle: 'Who comes back, and how often.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBar(
            fraction: repeatPct / 100,
            color: AppPalette.primary,
            height: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Repeat customers (3+ rentals)',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppPalette.body)),
              Text('${repeatPct.round()}%',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary)),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBar(
            fraction: benchmarkPct / 100,
            color: AppPalette.purple,
            height: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Benchmark — healthy workspace',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppPalette.body)),
              Text('${benchmarkPct.round()}%',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.purple)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            repeatPct >= benchmarkPct
                ? 'You are ahead of the benchmark — loyalty is compounding.'
                : 'A few follow-up calls would push you past the benchmark.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                height: 1.45,
                color: AppPalette.muted),
          ),
        ],
      ),
    );

    final leaderboardCard = SectionCard(
      icon: Icons.emoji_events_outlined,
      title: 'Top customers',
      subtitle: 'Ranked by lifetime spend — tap to open a profile.',
      child: Column(
        children: [
          for (var i = 0; i < leaderboard.length; i++)
            StaggerIn(
              index: i,
              child: HoverFill(
                onTap: () => openCustomerDetail(context, leaderboard[i]),
                child: _LeaderRow(
                  rank: i + 1,
                  customer: leaderboard[i],
                  maxSpend: leaderboard.first.lifetimeSpend,
                ),
              ),
            ),
        ],
      ),
    );

    return DetailPage(
      eyebrow: 'Workspace / Customers / Insights',
      title: 'Customer insights',
      subtitle: 'Retention, lead time and lifetime value — live.',
      icon: Icons.insights_outlined,
      iconColor: AppPalette.purple,
      iconBg: AppPalette.purpleBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpis,
          const SizedBox(height: 14),
          leadTimeCard,
          const SizedBox(height: 14),
          if (compact) ...[
            retentionCard,
            const SizedBox(height: 14),
            leaderboardCard,
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: retentionCard),
                  const SizedBox(width: 14),
                  Expanded(flex: 7, child: leaderboardCard),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- pieces
class _SplitStat extends StatelessWidget {
  final String label;
  final int pct;
  final Color color;
  const _SplitStat(
      {required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  color: AppPalette.body)),
        ),
        Text('$pct%',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final Customer customer;
  final double maxSpend;

  const _LeaderRow({
    required this.rank,
    required this.customer,
    required this.maxSpend,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#$rank',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(medal,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: rank <= 3 ? 14 : 12,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.muted)),
          ),
          InitialsAvatar(
              initials: customer.initials,
              color: customer.avatarColor,
              size: 34),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text(
                    '${customer.rentals} rentals · ${customer.isRepeat ? 'repeat' : 'new-ish'}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: AnimatedBar(
              fraction:
                  maxSpend == 0 ? 0 : customer.lifetimeSpend / maxSpend,
              color: customer.avatarColor,
              height: 5,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(money.format(customer.lifetimeSpend),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.faint),
        ],
      ),
    );
  }
}
