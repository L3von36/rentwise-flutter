import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/density.dart';
import '../../models/customer.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/motion.dart';
import 'customer_detail_screen.dart';
import '../../core/palette.dart';
import '../../core/app_locale.dart';

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
    final money = NumberFormat.compactCurrency(symbol: AppLocale.birr, decimalDigits: 1);

    final totalSpend =
        customers.fold<double>(0, (s, c) => s + c.lifetimeSpend);
    final repeat = customers.where((c) => c.isRepeat).length;
    final repeatPct =
        customers.isEmpty ? 0.0 : repeat / customers.length * 100;
    final avgValue =
        customers.isEmpty ? 0.0 : totalSpend / customers.length;

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
              label: AppLocale.t('Active relationships'),
              value: '${customers.length}',
              subtitle: AppLocale.t('In your directory'),
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.repeat_rounded,
              iconColor: AppPalette.purple,
              iconBg: AppPalette.purpleBg,
              label: AppLocale.t('Repeat rate'),
              value: '${repeatPct.round()}%',
              subtitle: '$repeat of ${customers.length} customers',
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.payments_outlined,
              iconColor: AppPalette.green,
              iconBg: AppPalette.greenBg,
              label: AppLocale.t('Avg lifetime value'),
              value: money.format(avgValue),
              subtitle: AppLocale.t('Per customer'),
            ),
          ),
          SizedBox(
            width: w,
            child: KpiCard(
              icon: Icons.schedule_rounded,
              iconColor: AppPalette.amber,
              iconBg: AppPalette.amberBg,
              label: AppLocale.t('Open follow-ups'),
              value: '${state.followUpsCount}',
              subtitle: AppLocale.t('No booking in 30+ days'),
            ),
          ),
        ],
      );
    });

    // Business target for repeat-rate health (app constant, not data).
    const benchmarkPct = 68.0;

    final retentionCard = SectionCard(
      icon: Icons.donut_small_rounded,
      title: AppLocale.t('Retention mix'),
      subtitle: AppLocale.t('Who comes back, and how often.'),
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
              Text(AppLocale.t('Repeat customers (3+ rentals)'),
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
              Text(AppLocale.t('Benchmark — healthy workspace'),
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
                ? AppLocale.t('You are ahead of the benchmark — loyalty is compounding.')
                : AppLocale.t('A few follow-up calls would push you past the benchmark.'),
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
      title: AppLocale.t('Top customers'),
      subtitle: AppLocale.t('Ranked by lifetime spend — tap to open a profile.'),
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
      eyebrow: AppLocale.t('Customers / Insights'),
      title: AppLocale.t('Customer insights'),
      subtitle: AppLocale.t('Retention, lead time and lifetime value — live.'),
      icon: Icons.insights_outlined,
      iconColor: AppPalette.purple,
      iconBg: AppPalette.purpleBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpis,
          const SizedBox(height: 14),
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
    final money = NumberFormat.currency(symbol: AppLocale.birr, decimalDigits: 0);
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
                    '${customer.rentals} ${customer.rentals == 1 ? 'rental' : 'rentals'} · ${customer.isRepeat ? 'repeat' : 'new'}',
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
