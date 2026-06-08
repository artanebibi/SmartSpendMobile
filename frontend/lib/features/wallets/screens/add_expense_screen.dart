import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.walletId});
  final String walletId;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  TransactionModel? _selected;
  bool _saving = false;
  String? _saveError;

  int get _walletId => int.tryParse(widget.walletId) ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<TransactionProvider>();
      if (tp.transactions.isEmpty) tp.load();
    });
  }

  Future<void> _save(
    WalletModel wallet,
    TransactionModel tx,
    List<Map<String, dynamic>> splits,
  ) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final ok = await context.read<WalletProvider>().linkExpense(
          walletId: _walletId,
          transactionId: tx.id,
          splits: splits,
        );

    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      setState(() {
        _saving = false;
        _saveError =
            context.read<WalletProvider>().error ?? 'Failed to add expense';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet =
        context.watch<WalletProvider>().findById(_walletId);
    if (wallet == null || wallet.members.isEmpty) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(backgroundColor: context.colors.bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_selected == null) {
      return _PickerView(
        wallet: wallet,
        onPicked: (tx) => setState(() => _selected = tx),
      );
    }

    return _SplitView(
      wallet: wallet,
      tx: _selected!,
      saving: _saving,
      error: _saveError,
      onBack: () => setState(() {
        _selected = null;
        _saveError = null;
      }),
      onSave: (wallet, tx, splits) => _save(wallet, tx, splits),
    );
  }
}

// ─── Phase 1: Pick a transaction ─────────────────────────────────────────────

class _PickerView extends StatefulWidget {
  const _PickerView({required this.wallet, required this.onPicked});
  final WalletModel wallet;
  final ValueChanged<TransactionModel> onPicked;

  @override
  State<_PickerView> createState() => _PickerViewState();
}

class _PickerViewState extends State<_PickerView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TransactionProvider>();
    final alreadyLinked = widget.wallet.transactions
        .map((t) => t.transactionId)
        .toSet();

    final expenses = tp.transactions
        .where((t) => t.isExpense)
        .where((t) => !alreadyLinked.contains(t.id))
        .where((t) =>
            _query.isEmpty ||
            t.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: 'Add Expense',
              onBack: () => context.pop(),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                style: GoogleFonts.inter(
                    fontSize: 14, color: context.colors.text),
                decoration: InputDecoration(
                  hintText: 'Search your expenses...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.muted),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.muted, size: 20),
                  filled: true,
                  fillColor: context.colors.card,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Your Expenses',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(already added to this wallet are hidden)',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tp.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : expenses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _query.isEmpty
                                  ? 'No expense transactions found.\nAdd expenses from the Transactions tab first.'
                                  : 'No expenses match "$_query".',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: expenses.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TxTile(
                              tx: expenses[i],
                              onTap: () => widget.onPicked(expenses[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, required this.onTap});
  final TransactionModel tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final svc = context.watch<ExchangeRateService>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.text,
                    ),
                  ),
                  Text(
                    '${tx.categoryName ?? 'Other'} · ${DateFormatter.groupLabel(tx.dateMade)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(svc.convertFromMkd(tx.price, currency), symbol: symbol),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.text,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Phase 2: Confirm split ───────────────────────────────────────────────────

class _SplitView extends StatefulWidget {
  const _SplitView({
    required this.wallet,
    required this.tx,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onSave,
  });

  final WalletModel wallet;
  final TransactionModel tx;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final Future<void> Function(
      WalletModel, TransactionModel, List<Map<String, dynamic>>) onSave;

  @override
  State<_SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<_SplitView> {
  bool _isCustom = false;
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final members = widget.wallet.members;
    final svc = context.read<ExchangeRateService>();
    final currency = context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final equalShareMkd = members.isEmpty ? 0.0 : widget.tx.price / members.length;
    final equalShare = svc.convertFromMkd(equalShareMkd, currency);
    _controllers = List.generate(
      members.length,
      (i) => TextEditingController(
        text: equalShare.toStringAsFixed(2),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _inputWidth(String text) {
    const double charWidth = 9.0;
    const double padding = 24.0;
    const double minWidth = 80.0;
    const double maxWidth = 140.0;
    final computed = text.length * charWidth + padding;
    return computed.clamp(minWidth, maxWidth);
  }

  double get _customTotal => _controllers.fold(
        0.0,
        (sum, c) => sum + (double.tryParse(c.text) ?? 0.0),
      );

  List<Map<String, dynamic>> _buildEqualSplits() {
    final members = widget.wallet.members;
    if (members.isEmpty) return [];
    final per = double.parse(
        (widget.tx.price / members.length).toStringAsFixed(2));
    double assigned = 0;
    final splits = <Map<String, dynamic>>[];
    for (int i = 0; i < members.length - 1; i++) {
      splits.add({'user_id': members[i].userId, 'share': per});
      assigned += per;
    }
    splits.add({
      'user_id': members.last.userId,
      'share': double.parse(
          (widget.tx.price - assigned).toStringAsFixed(2)),
    });
    return splits;
  }

  List<Map<String, dynamic>> _buildCustomSplits() {
    final svc = context.read<ExchangeRateService>();
    final currency = context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
    return List.generate(widget.wallet.members.length, (i) {
      final userCurrencyShare = double.tryParse(_controllers[i].text) ?? 0.0;
      return {
        'user_id': widget.wallet.members[i].userId,
        'share': double.parse(
            svc.convertToMkd(userCurrencyShare, currency).toStringAsFixed(2)),
      };
    });
  }

  void _onModeChanged(bool custom) {
    if (custom == _isCustom) return;
    setState(() {
      _isCustom = custom;
      if (!custom) {
        final svc = context.read<ExchangeRateService>();
        final currency = context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
        final members = widget.wallet.members;
        final per = members.isEmpty
            ? 0.0
            : svc.convertFromMkd(widget.tx.price / members.length, currency);
        for (final c in _controllers) {
          c.text = per.toStringAsFixed(2);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id ?? '';
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final svc = context.watch<ExchangeRateService>();
    final txConverted = svc.convertFromMkd(widget.tx.price, currency);
    final members = widget.wallet.members;
    // Validation and remaining bar work in user's preferred currency
    final customTotal = _isCustom ? _customTotal : txConverted;
    final remaining = txConverted - customTotal;
    final customValid = remaining.abs() < 0.02;
    final canSave =
        !widget.saving && (!_isCustom || customValid);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Confirm Split', onBack: widget.onBack),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.tx.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.text,
                                  ),
                                ),
                                Text(
                                  '${widget.tx.categoryName ?? 'Other'} · ${DateFormatter.groupLabel(widget.tx.dateMade)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(txConverted, symbol: symbol),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Equal / Custom toggle
                    Container(
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
                            selected: !_isCustom,
                            onTap: () => _onModeChanged(false),
                          ),
                          _SplitTab(
                            label: 'Custom',
                            selected: _isCustom,
                            onTap: () => _onModeChanged(true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remaining indicator (custom mode only)
                    if (_isCustom) ...[
                      _RemainingBar(
                        total: txConverted,
                        remaining: remaining,
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      _isCustom ? 'ENTER AMOUNT PER PERSON' : 'SPLIT EQUALLY BETWEEN',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Members list
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) {
                          final m = members[i];
                          final isMe = m.userId == myId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: m.color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      m.initials,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isMe ? 'You' : m.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.text,
                                    ),
                                  ),
                                ),
                                if (_isCustom)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        symbol,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: _inputWidth(_controllers[i].text),
                                        child: TextField(
                                          controller: _controllers[i],
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.text,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 8),
                                            filled: true,
                                            fillColor: context.colors.bg,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: AppColors.border),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: AppColors.border),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: AppColors.primary,
                                                  width: 1.5),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    CurrencyFormatter.format(
                                        members.isEmpty
                                            ? 0
                                            : txConverted / members.length,
                                        symbol: symbol),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    if (widget.error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: widget.error!),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canSave
                            ? () => widget.onSave(
                                  widget.wallet,
                                  widget.tx,
                                  _isCustom
                                      ? _buildCustomSplits()
                                      : _buildEqualSplits(),
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: widget.saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                _isCustom && !customValid
                                    ? 'Amounts must total ${CurrencyFormatter.format(txConverted, symbol: symbol)}'
                                    : 'Add to Wallet',
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
}

// ─── Remaining amount bar ─────────────────────────────────────────────────────

class _RemainingBar extends StatelessWidget {
  const _RemainingBar({required this.total, required this.remaining});
  final double total;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final symbol = CurrencyFormatter.symbolFor(
        context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD');
    final isOver = remaining < -0.01;
    final isExact = remaining.abs() < 0.02;
    final color = isExact
        ? AppColors.success
        : isOver
            ? AppColors.error
            : AppColors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isExact
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isExact
                  ? 'Amounts add up perfectly'
                  : isOver
                      ? 'Over by $symbol${remaining.abs().toStringAsFixed(2)}'
                      : '$symbol${remaining.toStringAsFixed(2)} left to assign',
              style: GoogleFonts.inter(fontSize: 12, color: color),
            ),
          ),
          Text(
            '${CurrencyFormatter.format(total - remaining, symbol: symbol)} / ${CurrencyFormatter.format(total, symbol: symbol)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Split mode tab ───────────────────────────────────────────────────────────

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

// ─── Shared header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
            title,
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
}
