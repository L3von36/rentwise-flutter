import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../widgets/cards.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/indicators.dart';

/// Owner-only performance monitor.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final trend = Seed.revenueTrend(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Owner monitor'),
          const SizedBox(height: 6),
          const Text('Reports',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text('Your business performance at a glance.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppColors.textMuted)),
          const SizedBox(height: 22),

          // top KPIs
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth < 760 ? 1 : 2;
            const gap = 16.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: w,
                  child: const KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: 'Gross revenue',
                    value: '\$28.9k',
                    subtitle: 'this month',
                    trailing: TrendChip(
                        text: '18.4%', positive: true),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: const KpiCard(
                    icon: Icons.donut_small_outlined,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Utilization',
                    value: '72.8%',
                    subtitle: 'this month',
                    trailing: TrendChip(
                        text: '+6.2%', positive: true),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // revenue trend
          SectionCard(
            title: 'Revenue trend',
            subtitle: _monthLabel(now),
            action: const Text('\$28.9k',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            child: SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  maxY: 5,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
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
                      getTooltipColor: (_) => AppColors.textDark,
                      getTooltipItem: (group, _, __, ___) {
                        final p = trend[group.x.toInt()];
                        return BarTooltipItem(
                          '\$${p.value.toStringAsFixed(1)}k',
                          const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
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
                            width: 30,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xFFB9B5F5),
                                AppColors.primary,
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // top categories
          SectionCard(
            title: 'Top category',
            subtitle: 'Seating drives the most revenue.',
            child: Column(
              children: [
                for (final cat in Seed.categoryRevenue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(cat.category,
                                  style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                            ),
                            Text(
                                '\$${_money(cat.amount)}',
                                style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            height: 6,
                            child: Stack(
                              children: [
                                Container(
                                    color: AppColors.primarySoft),
                                FractionallySizedBox(
                                  widthFactor: cat.amount /
                                      Seed.categoryRevenue.first.amount,
                                  child: Container(
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _money(num v) => v.toStringAsFixed(0).length <= 4
      ? v.toStringAsFixed(0)
      : '${(v / 1000).toStringAsFixed(1)}k';

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _xLabel(double value, List trend) {
    final idx = value.toInt();
    if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
    final show = idx == 0 || idx == (trend.length + 1) ~/ 2 - 1 || idx == trend.length - 1;
    if (!show) return const SizedBox.shrink();
    final d = trend[idx].day as DateTime;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Oct ${d.day}',
        style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: AppColors.textMuted),
      ),
    );
  }
}
