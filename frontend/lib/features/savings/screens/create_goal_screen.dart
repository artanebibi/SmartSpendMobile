import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
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

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  Color _color = _colorPalette[0];
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        // If to date is before from date, reset it
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = null;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final minDate = _fromDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? minDate.add(const Duration(days: 30)),
      firstDate: minDate,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  void _setQuickToDate(int days) {
    final baseDate = _fromDate ?? DateTime.now();
    setState(() => _toDate = baseDate.add(Duration(days: days)));
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0;

    if (name.isEmpty || target <= 0 || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<SavingsProvider>();

    // If fromDate is null, use today's date
    final fromDate = _fromDate ?? DateTime.now();

    final ok = await provider.create(
      name: name,
      currentAmount: 0,
      targetAmount: target,
      color: _color,
      from: fromDate,
      to: _toDate!,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to create goal. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildPreviewCard(),
                    const SizedBox(height: 24),
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildCreateButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          Text(
            'New Goal',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.track_changes_rounded, color: _color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Goal Name' : name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: name.isEmpty ? AppColors.muted : AppColors.darkText,
                  ),
                ),
                Text(
                  target != null && target > 0
                      ? '\$${target.toStringAsFixed(0)} target'
                      : 'Set a target amount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
                if (_toDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due ${DateFormatter.dayMonthYear(_toDate!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('GOAL NAME'),
        const SizedBox(height: 6),
        _buildInput(
          controller: _nameController,
          hint: 'e.g. Emergency Fund',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        _SectionLabel('TARGET AMOUNT'),
        const SizedBox(height: 6),
        _buildInput(
          controller: _targetController,
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Text('\$',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        _SectionLabel('START DATE (OPTIONAL)'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickFromDate,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(
                  _fromDate != null
                      ? DateFormatter.dayMonthYear(_fromDate!)
                      : 'Today',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _fromDate != null
                        ? AppColors.darkText
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
        const SizedBox(height: 16),

        _SectionLabel('TARGET DATE'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickToDate,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _toDate == null ? AppColors.error : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Text(
                  _toDate != null
                      ? DateFormatter.dayMonthYear(_toDate!)
                      : 'Select target date',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _toDate != null
                        ? AppColors.darkText
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
        const SizedBox(height: 10),

        // Quick date selection buttons
        _buildQuickDateButtons(),
        const SizedBox(height: 20),

        _SectionLabel('GOAL COLOR'),
        const SizedBox(height: 10),
        _buildColorPicker(),
      ],
    );
  }

  Widget _buildQuickDateButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickDateChip('2 weeks', 14),
        _buildQuickDateChip('1 month', 30),
        _buildQuickDateChip('3 months', 90),
        _buildQuickDateChip('6 months', 180),
      ],
    );
  }

  Widget _buildQuickDateChip(String label, int days) {
    return GestureDetector(
      onTap: () => _setQuickToDate(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    Widget? prefix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
        prefixIcon: prefix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: prefix != null
            ? const EdgeInsets.symmetric(vertical: 14)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colorPalette.map((c) {
        final selected = _color == c;
        return GestureDetector(
          onTap: () => setState(() => _color = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: selected
                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : Text('Create Goal',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.5,
      ),
    );
  }
}