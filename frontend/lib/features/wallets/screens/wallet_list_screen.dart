import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<WalletProvider>();
      if (auth.user != null) {
        provider.setCurrentUser(auth.user!.id);
      }
      provider.loadWallets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final wallets = provider.wallets;
    final totalOwed = provider.totalOwed;
    final totalOwedToMe = provider.totalOwedToMe;
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);
    final svc = context.watch<ExchangeRateService>();

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildJoinCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (totalOwed > 0 || totalOwedToMe > 0)
              SliverToBoxAdapter(
                child: _buildSettlementAlert(context, totalOwed, totalOwedToMe, symbol, svc, currency),
              ),
            if (totalOwed > 0 || totalOwedToMe > 0)
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (wallets.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No wallets yet. Tap + to create one.',
                    style: GoogleFonts.inter(color: AppColors.muted),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WalletCard(
                        wallet: wallets[i],
                        symbol: symbol,
                        onTap: () =>
                            context.push('/home/wallets/${wallets[i].id}'),
                      ),
                    ),
                    childCount: wallets.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: [
          Text(
            'Shared Wallets',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.colors.text,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/home/wallets/create'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _showJoinSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
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
                child: const Icon(Icons.group_add_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join a Wallet',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.text,
                      ),
                    ),
                    Text(
                      'Have an invite code? Tap to enter it.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showJoinSheet(BuildContext context) async {
    final codeCtrl = TextEditingController();
    String? sheetError;
    bool joining = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> submit() async {
            final code = codeCtrl.text.trim();
            if (code.isEmpty) {
              setSheetState(() => sheetError = 'Please enter an invite code');
              return;
            }
            setSheetState(() {
              joining = true;
              sheetError = null;
            });

            final wallet =
                await context.read<WalletProvider>().joinWalletByCode(code);

            if (!ctx.mounted) return;
            if (wallet != null) {
              Navigator.pop(ctx);
              context.read<WalletProvider>().loadWallets();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Joined "${wallet.name}"!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            } else {
              final err = context.read<WalletProvider>().error ??
                  'Invalid invite code';
              setSheetState(() {
                joining = false;
                sheetError = err;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Join a Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ctx.colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the invite code shared with you.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  autofocus: true,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: ctx.colors.text),
                  decoration: InputDecoration(
                    hintText: 'Paste invite code here',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.muted),
                    filled: true,
                    fillColor: ctx.colors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                    errorText: sheetError,
                    errorMaxLines: 2,
                  ),
                  onSubmitted: (_) => joining ? null : submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: joining ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: joining
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text(
                            'Join Wallet',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Defer dispose to the next frame so the sheet's close animation
    // finishes before the controller is freed (keyboard hide can trigger
    // a rebuild of the TextField after showModalBottomSheet returns).
    WidgetsBinding.instance.addPostFrameCallback((_) => codeCtrl.dispose());
  }

  Widget _buildSettlementAlert(BuildContext context, double totalOwed,
      double totalOwedToMe, String symbol, ExchangeRateService svc, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(AppColors.orange.withValues(alpha: 0.10), context.colors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (totalOwed > 0)
                    Text(
                      'You owe ${CurrencyFormatter.format(svc.convertFromMkd(totalOwed, currency), symbol: symbol)} total',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  if (totalOwedToMe > 0)
                    Text(
                      '${CurrencyFormatter.format(svc.convertFromMkd(totalOwedToMe, currency), symbol: symbol)} owed to you',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/home/wallets/settle'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Settle Up',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.symbol, required this.onTap});
  final WalletModel wallet;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final svc = context.watch<ExchangeRateService>();
    final spent = svc.convertFromMkd(wallet.totalSpent, currency);
    final double? goal = null; // monthly goal not yet in API response
    final pct = goal != null && goal > 0
        ? (spent / goal).clamp(0.0, 1.0)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _AvatarStack(members: wallet.members),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.text,
                        ),
                      ),
                      Text(
                        '${wallet.memberCount} members',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(spent, symbol: symbol),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.text,
                      ),
                    ),
                    Text(
                      'total spent',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: context.colors.bg,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${CurrencyFormatter.format(spent, symbol: symbol)} of ${CurrencyFormatter.format(goal!, symbol: symbol)} goal',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});
  final List<WalletMember> members;

  static const _size = 32.0;
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(4).toList();
    final totalWidth = _size + (visible.length - 1) * (_size - _overlap);

    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        children: visible.asMap().entries.map((e) {
          final m = e.value;
          return Positioned(
            left: e.key * (_size - _overlap),
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: m.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  m.initials,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
