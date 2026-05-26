import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/services/exchange_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/saving_model.dart';
import '../providers/savings_provider.dart';

const _colorPalette = [
  Color(0xFF3D7EFF),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
];

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

  Future<void> _showAddContribution(SavingModel goal, String symbol) async {
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
            prefixText: '$symbol ',
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
      // Capture providers before async gaps
      final currency =
          context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
      final exchangeSvc = context.read<ExchangeRateService>();
      final savingsProvider = context.read<SavingsProvider>();
      final mkdAmount =
          await exchangeSvc.exchangeForDbStore(amount, currency);
      await savingsProvider.addContribution(widget.id, mkdAmount);
      await _loadContributions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingsProvider>();
    final goal =
        provider.savings.where((s) => s.id == widget.id).firstOrNull;
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final exchangeSvc = context.watch<ExchangeRateService>();

    if (goal == null) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(
          backgroundColor: context.colors.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: context.colors.text),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, goal, symbol)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
                child: _buildProgressCard(context, goal, symbol, exchangeSvc, currency)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
                child: _buildAddButton(context, goal, symbol)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            if (_contributions.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildHistoryHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                  child: _buildContributionList(symbol, exchangeSvc, currency)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SavingModel goal, String symbol) {
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
                color: context.colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: context.colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goal.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _showEditSheet(context, goal, symbol),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet(
      BuildContext context, SavingModel goal, String symbol) async {
    final currency =
        context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final exchangeSvc = context.read<ExchangeRateService>();
    final provider = context.read<SavingsProvider>();

    final result = await showModalBottomSheet<_EditGoalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGoalSheet(
        goal: goal,
        symbol: symbol,
        currency: currency,
        exchangeSvc: exchangeSvc,
      ),
    );

    if (result == null || !mounted) return;

    final ok = await provider.update(
      id: widget.id,
      name: result.name,
      targetAmountMkd: result.targetAmountMkd,
      color: result.color,
      deadline: result.deadline,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to update goal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildProgressCard(BuildContext context, SavingModel goal, String symbol,
      ExchangeRateService exchangeSvc, String currency) {
    final pct = goal.percentage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 176,
              height: 176,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  percentage: pct / 100,
                  color: goal.color,
                  trackColor: context.colors.bg,
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
                          color: context.colors.text,
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
              CurrencyFormatter.format(
                  exchangeSvc.convertFromMkd(goal.currentAmount, currency),
                  symbol: symbol),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.text,
              ),
            ),
            Text(
              'of ${CurrencyFormatter.format(exchangeSvc.convertFromMkd(goal.targetAmount, currency), symbol: symbol)} goal',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.muted),
            ),
            if (goal.deadline != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.secondaryBg,
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

  Widget _buildAddButton(BuildContext context, SavingModel goal, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => _showAddContribution(goal, symbol),
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
          color: context.colors.text,
        ),
      ),
    );
  }

  Widget _buildContributionList(String symbol, ExchangeRateService exchangeSvc,
      String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
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
                      color: context.colors.secondaryBg,
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
                            color: context.colors.text,
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
                    '+${CurrencyFormatter.format(exchangeSvc.convertFromMkd(c.amount, currency), symbol: symbol)}',
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

// ─── Edit goal sheet ─────────────────────────────────────────────────────────

class _EditGoalResult {
  const _EditGoalResult({
    required this.name,
    required this.targetAmountMkd,
    required this.color,
    this.deadline,
  });
  final String name;
  final double targetAmountMkd;
  final Color color;
  final DateTime? deadline;
}

class _EditGoalSheet extends StatefulWidget {
  const _EditGoalSheet({
    required this.goal,
    required this.symbol,
    required this.currency,
    required this.exchangeSvc,
  });
  final SavingModel goal;
  final String symbol;
  final String currency;
  final ExchangeRateService exchangeSvc;

  @override
  State<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<_EditGoalSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late Color _color;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final display = widget.exchangeSvc
        .convertFromMkd(widget.goal.targetAmount, widget.currency);
    _nameCtrl = TextEditingController(text: widget.goal.name);
    _targetCtrl = TextEditingController(
        text: display > 0 ? display.toStringAsFixed(0) : '');
    _color = widget.goal.color;
    _deadline = widget.goal.deadline;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    if (name.isEmpty || target <= 0) return;
    final mkd =
        await widget.exchangeSvc.exchangeForDbStore(target, widget.currency);
    if (!mounted) return;
    Navigator.pop(
      context,
      _EditGoalResult(
          name: name, targetAmountMkd: mkd, color: _color, deadline: _deadline),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.border),
    );
    const focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Edit Goal',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.text,
                ),
              ),
              const SizedBox(height: 20),

              _label('GOAL NAME'),
              TextField(
                controller: _nameCtrl,
                style:
                    GoogleFonts.inter(fontSize: 14, color: context.colors.text),
                decoration: InputDecoration(
                  hintText: 'e.g. Emergency Fund',
                  hintStyle:
                      GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
                  filled: true,
                  fillColor: context.colors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedBorder,
                ),
              ),
              const SizedBox(height: 16),

              _label('TARGET AMOUNT'),
              TextField(
                controller: _targetCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    GoogleFonts.inter(fontSize: 14, color: context.colors.text),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '${widget.symbol} ',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: context.colors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: focusedBorder,
                ),
              ),
              const SizedBox(height: 16),

              _label('TARGET DATE (OPTIONAL)'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deadline ??
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 10),
                        );
                        if (picked != null) setState(() => _deadline = picked);
                      },
                      child: Container(
                        height: 48,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.colors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _deadline != null
                                  ? DateFormatter.dayMonthYear(_deadline!)
                                  : 'No deadline',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _deadline != null
                                    ? context.colors.text
                                    : AppColors.muted,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_deadline != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: context.colors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.muted),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              _label('GOAL COLOR'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colorPalette.map((c) {
                  final sel = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Save Changes',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
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
    required this.trackColor,
  });

  final double percentage;
  final Color color;
  final Color trackColor;

  static const _strokeWidth = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = trackColor
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
      old.percentage != percentage || old.color != color || old.trackColor != trackColor;
}
