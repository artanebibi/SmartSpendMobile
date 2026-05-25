import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/stats_provider.dart';

// Chart color palette matching React POC
const _pieColors = [
  Color(0xFFF97316),
  Color(0xFF3D7EFF),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
];

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);
    context.read<StatsProvider>().load(from: from, to: to);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month',
    );
    if (picked != null && mounted) {
      setState(() => _month = DateTime(picked.year, picked.month));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: _buildTabSwitcher()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (stats.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (stats.error != null && stats.pieData.isEmpty && stats.monthlyData.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bar_chart_outlined,
                          size: 48, color: AppColors.muted),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load statistics',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stats.error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _load,
                        child: Text('Retry',
                            style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_tab == 0)
              SliverToBoxAdapter(child: _buildOverview(stats, symbol))
            else if (_tab == 1)
              SliverToBoxAdapter(child: _buildMonthly(stats, symbol))
            else
              SliverToBoxAdapter(child: _buildCategories(stats, symbol)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Statistics',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormatter.monthYear(_month),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    const tabs = ['Overview', 'Monthly', 'Categories'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final active = _tab == e.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Overview Tab ────────────────────────────────────────────────────────────

  Widget _buildOverview(StatsProvider stats, String symbol) {
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day.toDouble();
    final avgPerDay = daysInMonth > 0 ? stats.totalExpenses / daysInMonth : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2×2 stat cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                label: 'Total Income',
                value: CurrencyFormatter.format(stats.totalIncome, symbol: symbol),
                valueColor: AppColors.success,
                sub: '↑ This month',
                subColor: AppColors.success,
              ),
              _StatCard(
                label: 'Total Expenses',
                value: CurrencyFormatter.format(stats.totalExpenses, symbol: symbol),
                valueColor: AppColors.error,
                sub: '↓ This month',
                subColor: AppColors.error,
              ),
              _StatCard(
                label: 'Net Savings',
                value: CurrencyFormatter.format(stats.netSavings, symbol: symbol),
                valueColor: stats.netSavings >= 0
                    ? AppColors.success
                    : AppColors.error,
                sub: stats.netSavings >= 0 ? 'Positive' : 'Negative',
                subColor: stats.netSavings >= 0
                    ? AppColors.success
                    : AppColors.error,
              ),
              _StatCard(
                label: 'Avg / Day',
                value: CurrencyFormatter.format(avgPerDay.toDouble(), symbol: symbol),
                valueColor: AppColors.darkText,
                sub: 'Expenses',
                subColor: AppColors.muted,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildPieCard(stats),
        const SizedBox(height: 16),
        _buildBarCard(stats, symbol),
      ],
    );
  }

  Widget _buildPieCard(StatsProvider stats) {
    final hasData = stats.pieData.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending by Category',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              _emptyChart('No spending data for this period')
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sections: stats.pieData.asMap().entries.map((e) {
                          final color = _pieColors[e.key % _pieColors.length];
                          return PieChartSectionData(
                            color: color,
                            value: e.value.percentage,
                            radius: 26,
                            showTitle: false,
                          );
                        }).toList(),
                        centerSpaceRadius: 42,
                        sectionsSpace: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: stats.pieData.asMap().entries.map((e) {
                        final color = _pieColors[e.key % _pieColors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.value.category,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.darkText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${e.value.percentage.toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarCard(StatsProvider stats, String symbol) {
    final hasData = stats.monthlyData.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trend',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              _emptyChart('No monthly data for this period')
            else ...[
              SizedBox(
                height: 140,
                child: _buildBarChart(stats, symbol, showIncome: false),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: AppColors.primary, label: 'Income'),
                  const SizedBox(width: 16),
                  _LegendDot(
                      color: const Color(0xFFFCA5A5), label: 'Expenses'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Monthly Tab ─────────────────────────────────────────────────────────────

  Widget _buildMonthly(StatsProvider stats, String symbol) {
    final hasData = stats.monthlyData.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Expenses',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormatter.monthYear(_month),
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              _emptyChart('No data for this period')
            else
              SizedBox(
                height: 220,
                child: _buildBarChart(stats, symbol, showIncome: false),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Categories Tab ───────────────────────────────────────────────────────────

  Widget _buildCategories(StatsProvider stats, String symbol) {
    if (stats.pieData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _emptyChart('No category data for this period'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: stats.pieData.asMap().entries.map((e) {
          final color = _pieColors[e.key % _pieColors.length];
          final slice = e.value;
          final pct = slice.percentage / 100;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slice.category,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    Text(
                      '${slice.percentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(slice.amount, symbol: symbol),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: AppColors.lightBg,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Shared bar chart builder ─────────────────────────────────────────────────

  Widget _buildBarChart(StatsProvider stats, String symbol, {required bool showIncome}) {
    final data = stats.monthlyData;
    final maxY = data.fold(0.0, (m, b) => m > b.expense ? m : b.expense);
    final yInterval = maxY > 0 ? (maxY / 4).ceilToDouble() : 500;

    return BarChart(
      BarChartData(
        maxY: maxY > 0 ? maxY * 1.2 : 1000,
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: e.value.expense,
                color: const Color(0xFFFCA5A5),
                width: showIncome ? 10 : 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              ),
              if (showIncome)
                BarChartRodData(
                  toY: e.value.income,
                  color: AppColors.primary,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[i].month,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval.toDouble(),
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.darkText,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              CurrencyFormatter.format(rod.toY, symbol: symbol),
              GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyChart(String message) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.sub,
    required this.subColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String sub;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 10, color: subColor),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
