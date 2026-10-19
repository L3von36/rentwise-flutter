import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/indicators.dart';
import '../../widgets/motion.dart';
import '../../widgets/restricted.dart';
import '../../state/workspace_state.dart';
import '../../models/pickup.dart' show RevenuePoint, CategoryRevenue;
import '../../core/palette.dart';

/// Owner-only performance console. Every figure on this screen is
/// computed from live workspace state (metrics doc + orders) — nothing
/// is hardcoded, so the page stays honest as the business grows.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();

    // Defensive guard: navigation already hides Reports from employees —
    // this keeps financial data unreachable even if the screen mounts.
    if (!state.isOwner) {
      return Padding(
        padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
            Density.pagePad(context), 24),
        child: const RestrictedPanel(area: 'Reports'),
      );
    }

    final trend = state.revenueTrend;
    final momentum = state.earningsTrendPct;

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: Density.compact(context) ? 17 : 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppPalette.ink)),
          const SizedBox(height: 16),

          // hero — month headline + live stat tiles
          StaggerIn(
            index: 0,
            child: _PerformanceHero(
              monthLabel: DateFormat('MMMM y').format(DateTime.now()),
              revenueK: state.monthGrossRevenueK,
              utilization: state.utilization,
              momentumPct: momentum,
            ),
          ),
          const SizedBox(height: 14),

          // live KPI grid
          StaggerIn(
            index: 1,
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth < 820 ? 2 : 2;
              const gap = 14.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      icon: Icons.request_quote_outlined,
                      iconColor: AppPalette.amber,
                      iconBg: AppPalette.amberBg,
                      label: 'Awaiting payment',
                      value:
                          '\$${state.awaitingPaymentTotal.toStringAsFixed(0)}',
                      subtitle: 'open receivables',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      icon: Icons.assignment_late_outlined,
                      iconColor:
                          state.returnsLateCount > 0
                              ? AppPalette.red
                              : AppPalette.green,
                      iconBg:
                          state.returnsLateCount > 0
                              ? AppPalette.redBg
                              : AppPalette.greenBg,
                      label: 'Late returns',
                      value: '${state.returnsLateCount}',
                      subtitle: state.returnsLateCount > 0
                          ? 'need follow-up'
                          : 'all on time',
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),

          // revenue trend
          StaggerIn(
            index: 2,
            child: SectionCard(
              icon: Icons.show_chart_rounded,
              title: 'Revenue trend',
              subtitle: DateFormat('MMMM y').format(DateTime.now()),
              action: _MomentumChip(pct: momentum),
              child: _TrendChart(trend: trend),
            ),
          ),
          const SizedBox(height: 14),

          // categories + pipeline
          StaggerIn(
            index: 3,
            child: LayoutBuilder(builder: (context, c) {
              const gap = 14.0;
              final stacked = c.maxWidth < 900;
              final categories = _CategoryPanel(series: state.categorySeries);
              return stacked
                  ? Column(
                      children: [
                        categories,
                        const SizedBox(height: gap),
                        const _PipelinePanel(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: categories),
                        const SizedBox(width: gap),
                        const Expanded(child: _PipelinePanel()),
                      ],
                    );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- hero

/// Gradient month-performance banner mirroring the Access & roles hero.
class _PerformanceHero extends StatelessWidget {
  final String monthLabel;
  final double revenueK;
  final double utilization;
  final double momentumPct;

  const _PerformanceHero({
    required this.monthLabel,
    required this.revenueK,
    required this.utilization,
    required this.momentumPct,
  });

  @override
  Widget build(BuildContext context) {
    final compact = Density.compact(context);

    final headline = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(Icons.insights_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$monthLabel performance',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ),
      ],
    );

    final stats = [
      _HeroStat(value: '\$${revenueK.toStringAsFixed(1)}k', label: 'Revenue'),
      _HeroStat(
          value: '${utilization.toStringAsFixed(1)}%',
          label: 'Utilization'),
      _HeroStat(
          value:
              '${momentumPct >= 0 ? '+' : '-'}${momentumPct.abs().toStringAsFixed(1)}%',
          label: 'Momentum'),
    ];
    final statRow = Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: stats[i]),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppPalette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
        boxShadow: AppShadow.card(
            opacity: AppPalette.dark ? 0.5 : 0.18),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: 14),
                statRow,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: headline),
                const SizedBox(width: 18),
                SizedBox(width: 270, child: statRow),
              ],
            ),
    );
  }
}

/// Translucent stat tile used inside the performance hero.
class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safety net: values scale down instead of wrapping ('+12.5%'
          // used to break onto two lines at narrow hero widths).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(height: 1),
          // Safety net: labels scale down instead of ellipsizing at any
          // width or system text scale (e.g. 'UTILIZATION' on the 270px
          // desktop hero row).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.white.withOpacity(0.72))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- chips

/// Live day-momentum chip — green up, red down, flat dot at ~0%.
class _MomentumChip extends StatelessWidget {
  final double pct;
  const _MomentumChip({required this.pct});

  @override
  Widget build(BuildContext context) {
    if (pct.abs() < 0.05) {
      return const TrendChip.flat(text: 'steady');
    }
    return TrendChip(
      text:
          '${pct >= 0 ? '+' : '-'}${pct.abs().toStringAsFixed(1)}%',
      positive: pct >= 0,
    );
  }
}

// ---------------------------------------------------------------- chart

/// Live revenue bar chart: dynamic maxY, dynamic month/day x-labels and
/// a live summary footer (best day · daily average · days booked).
class _TrendChart extends StatelessWidget {
  final List<RevenuePoint> trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const _ChartEmpty(
          message: 'No trend data loaded for this workspace yet.');
    }

    final total = trend.fold<double>(0, (s, p) => s + p.value);
    if (total <= 0) {
      return const _ChartEmpty(
          message:
              'No revenue booked yet this month — new bookings appear here '
              'as soon as payments are recorded.');
    }

    final peak = trend
        .map((p) => p.value)
        .reduce((a, b) => b > a ? b : a);
    final maxY =
        (peak * 1.25).ceilToDouble().clamp(5.0, double.infinity).toDouble();
    final best = trend.reduce((a, b) => b.value > a.value ? b : a);
    final avg = total / trend.length;
    final booked = trend.where((p) => p.value > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 210,
          child: LayoutBuilder(builder: (context, box) {
            final barWidth = ((box.maxWidth - 8) / trend.length * 0.52)
                .clamp(10.0, 34.0)
                .toDouble();
            return BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceBetween,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 2,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppPalette.stroke,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: maxY / 2,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(_axisLabel(value),
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10,
                                color: AppPalette.faint)),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) =>
                          _xLabel(value, trend),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppPalette.ink,
                    getTooltipItem: (group, _, __, ___) {
                      final p = trend[group.x.toInt()];
                      return BarTooltipItem(
                        '${DateFormat('MMM d').format(p.day)} · '
                            '\$${p.value.toStringAsFixed(1)}k',
                        TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppPalette.dark
                                ? AppPalette.canvas
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < trend.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: trend[i].value,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppPalette.dark
                                  ? const Color(0xFF3D3A8C)
                                  : const Color(0xFFB9B5F5),
                              AppPalette.primary,
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppPalette.fill,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                  child: _ChartStat(
                      label: 'Best day',
                      value:
                          '\$${best.value.toStringAsFixed(1)}k · ${DateFormat('MMM d').format(best.day)}')),
              _vDivider(),
              Expanded(
                  child: _ChartStat(
                      label: 'Daily average',
                      value: '\$${avg.toStringAsFixed(1)}k')),
              _vDivider(),
              Expanded(
                  child: _ChartStat(
                      label: 'Days booked',
                      value: '$booked of ${trend.length}')),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _vDivider() => Container(
        width: 1,
        height: 26,
        color: AppPalette.stroke,
      );

  static String _axisLabel(double v) {
    if (v == 0) return '0';
    final s = v.toStringAsFixed(1);
    return '\$${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
  }

  Widget _xLabel(double value, List<RevenuePoint> trend) {
    final idx = value.toInt();
    if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
    final show = idx == 0 ||
        idx == (trend.length + 1) ~/ 2 - 1 ||
        idx == trend.length - 1;
    if (!show) return const SizedBox.shrink();
    final d = trend[idx].day;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        DateFormat('MMM d').format(d),
        style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: AppPalette.muted),
      ),
    );
  }
}

/// Honest empty state replacing a flat zeroed chart.
class _ChartEmpty extends StatelessWidget {
  final String message;
  const _ChartEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.fill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppPalette.stroke),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 30, color: AppPalette.faint),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppPalette.muted)),
          ),
        ],
      ),
    );
  }
}

class _ChartStat extends StatelessWidget {
  final String label;
  final String value;
  const _ChartStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppPalette.faint)),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink)),
      ],
    );
  }
}

// ---------------------------------------------------------------- panels

/// Ranked revenue split with rank chips, share % and per-rank color bars.
class _CategoryPanel extends StatelessWidget {
  final List<CategoryRevenue> series;
  const _CategoryPanel({required this.series});

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppPalette.primary,
      AppPalette.purple,
      AppPalette.blue,
      AppPalette.amber,
      AppPalette.green,
    ];

    return SectionCard(
      icon: Icons.donut_large_rounded,
      iconColor: AppPalette.purple,
      iconBg: AppPalette.purpleBg,
      title: 'Top categories',
      child: series.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text('No category revenue recorded yet.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppPalette.muted)),
              ),
            )
          : _CategoryList(series: series, colors: colors),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<CategoryRevenue> series;
  final List<Color> colors;
  const _CategoryList({required this.series, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = series.fold<double>(0, (s, c) => s + c.amount);
    final peak =
        series.map((c) => c.amount).reduce((a, b) => b > a ? b : a);

    return Column(
      children: [
        for (var i = 0; i < series.length; i++) ...[
          _CategoryRow(
            rank: i + 1,
            color: colors[i % colors.length],
            category: series[i].category,
            amount: series[i].amount,
            sharePct: total > 0 ? series[i].amount / total * 100 : 0,
            widthFactor: peak > 0 ? series[i].amount / peak : 0.0,
          ),
          if (i < series.length - 1) const SizedBox(height: 16),
        ],
        const SizedBox(height: 4),
        const Divider(height: 20),
        Row(
          children: [
            Expanded(
              child: Text('Combined this month',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.muted)),
            ),
            Text(
                '\$${NumberFormat.decimalPattern().format(total.round())}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink)),
          ],
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final int rank;
  final Color color;
  final String category;
  final double amount;
  final double sharePct;
  final double widthFactor;

  const _CategoryRow({
    required this.rank,
    required this.color,
    required this.category,
    required this.amount,
    required this.sharePct,
    required this.widthFactor,
  });

  String _amountLabel() => amount >= 10000
      ? '\$${(amount / 1000).toStringAsFixed(1)}k'
      : '\$${NumberFormat.decimalPattern().format(amount.round())}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$rank',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(category,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink)),
            ),
            Text(_amountLabel(),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primary)),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Text('${sharePct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.muted)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: color.withOpacity(0.12)),
                FractionallySizedBox(
                  widthFactor: widthFactor.clamp(0.0, 1.0).toDouble(),
                  child: Container(color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Live operational pipeline — counts pulled straight from the orders.
class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();

    return SectionCard(
      icon: Icons.route_rounded,
      iconColor: AppPalette.blue,
      iconBg: AppPalette.blueBg,
      title: 'Order pipeline',
      child: Column(
        children: [
          _PipeRow(
            icon: Icons.inventory_2_outlined,
            color: AppPalette.primary,
            bg: AppPalette.primarySoft,
            label: 'Preparing',
            sub: 'being staged & packed',
            count: state.preparingCount,
          ),
          const Divider(height: 18),
          _PipeRow(
            icon: Icons.request_page_outlined,
            color: AppPalette.amber,
            bg: AppPalette.amberBg,
            label: 'Needs payment',
            sub: state.awaitingPaymentTotal > 0
                ? '\$${state.awaitingPaymentTotal.toStringAsFixed(0)} awaiting'
                : 'nothing outstanding',
            count: state.needsPaymentCount,
          ),
          const Divider(height: 18),
          _PipeRow(
            icon: Icons.local_shipping_outlined,
            color: AppPalette.blue,
            bg: AppPalette.blueBg,
            label: 'With customer',
            sub: 'on rent · pickup only',
            count: state.outForDeliveryCount,
          ),
          const Divider(height: 18),
          _PipeRow(
            icon: Icons.event_available_outlined,
            color: AppPalette.green,
            bg: AppPalette.greenBg,
            label: 'Returns today',
            sub: 'scheduled check-ins',
            count: state.returnsTodayCount,
          ),
          const Divider(height: 18),
          _PipeRow(
            icon: Icons.schedule_outlined,
            color: state.returnsLateCount > 0
                ? AppPalette.red
                : AppPalette.green,
            bg: state.returnsLateCount > 0
                ? AppPalette.redBg
                : AppPalette.greenBg,
            label: 'Late returns',
            sub: state.returnsLateCount > 0
                ? 'follow up with customers'
                : 'everything on schedule',
            count: state.returnsLateCount,
          ),
        ],
      ),
    );
  }
}

class _PipeRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final String sub;
  final int count;

  const _PipeRow({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.sub,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isLate = label == 'Late returns' && count > 0;
    return Row(
      children: [
        IconChipLite(icon: icon, color: color, bg: bg, size: 34),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppPalette.muted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isLate ? AppPalette.redBg : AppPalette.fill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isLate ? AppPalette.red : AppPalette.ink)),
        ),
      ],
    );
  }
}
