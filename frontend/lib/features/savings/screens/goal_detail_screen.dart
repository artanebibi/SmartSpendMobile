import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/saving_model.dart';
import '../providers/savings_provider.dart';

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  List<Contribution> _contributions = [];

  @override
  void initState() {
    super.initState();
    _loadContributions();
  }

  Future<void> _loadContributions() async {
    final list = await context
        .read<SavingsProvider>()
        .getContributions(widget.id);
    if (mounted) setState(() => _contributions = list);
  }

  Future<void> _showAddContribution(SavingModel goal) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Contribution',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: '0.00',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Add',
                style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final amount = double.tryParse(controller.text) ?? 0;
      if (amount <= 0) return;
      await context
          .read<SavingsProvider>()
          .addContribution(widget.id, amount);
      await _loadContributions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final goal =
        provider.savings.where((s) => s.id == widget.id).firstOrNull;

    if (goal == null) {
      return Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: AppColors.lightBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.darkText),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, goal)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
                child: _buildProgressCard(context, goal)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
                child: _buildAddButton(context, goal)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            if (_contributions.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildHistoryHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                  child: _buildContributionList()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SavingModel goal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.darkText),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goal.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, SavingModel goal) {
    final pct = goal.percentage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Circular progress
            SizedBox(
              width: 176,
              height: 176,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  percentage: pct / 100,
                  color: goal.color,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        'complete',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              CurrencyFormatter.format(goal.amount),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            Text(
              'of ${CurrencyFormatter.format(goal.targetAmount)} goal',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.muted),
            ),

            if (goal.deadline != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🗓 Due ${DateFormatter.dayMonthYear(goal.deadline!)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, SavingModel goal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => _showAddContribution(goal),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            '+ Add Contribution',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Contribution History',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
      ),
    );
  }

  Widget _buildContributionList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _contributions.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 60),
          itemBuilder: (_, i) {
            final c = _contributions[i];
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contribution',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                        Text(
                          DateFormatter.dayMonthYear(c.date),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${CurrencyFormatter.format(c.amount)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Circular progress custom painter ────────────────────────────────────────

class _CircularProgressPainter extends CustomPainter {
  const _CircularProgressPainter({
    required this.percentage,
    required this.color,
  });

  final double percentage;
  final Color color;

  static const _strokeWidth = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = AppColors.lightBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (percentage <= 0) return;

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2,                          // start at top
      2 * pi * percentage.clamp(0, 1),  // sweep angle
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.percentage != percentage || old.color != color;
}
