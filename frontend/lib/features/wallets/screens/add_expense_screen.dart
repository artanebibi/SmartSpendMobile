import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.walletId});
  final String walletId;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descController = TextEditingController();
  String _amount = '0';
  WalletMember? _payer;
  bool _equalSplit = true;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _onNumKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = '0';
        }
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount == '0') {
          _amount = key;
        } else {
          _amount += key;
        }
      }
    });
  }

  void _save(WalletModel wallet) {
    final amount = double.tryParse(_amount) ?? 0;
    if (amount <= 0) return;
    final desc = _descController.text.trim();
    if (desc.isEmpty) return;
    final payer = _payer ?? kMockMe;

    context.read<WalletProvider>().addExpense(
          walletId: widget.walletId,
          expense: WalletExpense(
            description: desc,
            amount: amount,
            payer: payer,
            date: DateTime.now(),
            splitWith: wallet.members,
          ),
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final wallet =
        context.watch<WalletProvider>().findById(widget.walletId);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(backgroundColor: AppColors.lightBg, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _payer ??= kMockMe;
    final amount = double.tryParse(_amount) ?? 0;
    final perPerson =
        amount > 0 ? amount / wallet.members.length : 0.0;

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
                    const SizedBox(height: 8),
                    _buildAmountDisplay(),
                    const SizedBox(height: 16),
                    _buildNumPad(),
                    const SizedBox(height: 20),
                    _sectionLabel('DESCRIPTION'),
                    const SizedBox(height: 6),
                    _buildDescInput(),
                    const SizedBox(height: 20),
                    _sectionLabel('PAID BY'),
                    const SizedBox(height: 10),
                    _buildPayerSelector(wallet.members),
                    const SizedBox(height: 20),
                    _buildSplitToggle(),
                    if (amount > 0) ...[
                      const SizedBox(height: 16),
                      _buildBreakdown(wallet.members, perPerson),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _save(wallet),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Add Expense',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
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
                color: context.colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: context.colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Add Expense',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '\$',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _amount,
            style: GoogleFonts.inter(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: context.colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumPad() {
    const keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '.', '0', '⌫',
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: keys.map((k) => _NumKey(label: k, onTap: _onNumKey)).toList(),
    );
  }

  Widget _buildDescInput() {
    return TextField(
      controller: _descController,
      style: GoogleFonts.inter(fontSize: 14, color: context.colors.text),
      decoration: InputDecoration(
        hintText: 'Add a description...',
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
        filled: true,
        fillColor: context.colors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPayerSelector(List<WalletMember> members) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: members.map((m) {
        final selected = _payer?.name == m.name;
        return GestureDetector(
          onTap: () => setState(() => _payer = m),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: selected ? 1.0 : 0.4,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: m.color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: m.color.withValues(alpha: 0.4),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      m.initials,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m.name == kMockMe.name ? 'You' : m.name,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: context.colors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSplitToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          _SplitTab(
            label: 'Equal Split',
            selected: _equalSplit,
            onTap: () => setState(() => _equalSplit = true),
          ),
          _SplitTab(
            label: 'Custom',
            selected: !_equalSplit,
            onTap: () => setState(() => _equalSplit = false),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(List<WalletMember> members, double perPerson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Per person breakdown',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration:
                        BoxDecoration(color: m.color, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        m.initials,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    m.name == kMockMe.name ? 'You' : m.name,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: context.colors.text),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(perPerson),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
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

class _NumKey extends StatefulWidget {
  const _NumKey({required this.label, required this.onTap});
  final String label;
  final ValueChanged<String> onTap;

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap(widget.label);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? context.colors.secondaryBg : context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: context.colors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitTab extends StatelessWidget {
  const _SplitTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
