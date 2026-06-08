import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key, required this.walletId});
  final String walletId; // comes as String from router param

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late final int _id;

  @override
  void initState() {
    super.initState();
    _id = int.tryParse(widget.walletId) ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<WalletProvider>();
      if (auth.user != null) provider.setCurrentUser(auth.user!.id);
      provider.loadWalletDetail(_id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final wallet = provider.findById(_id);
    final myUserId =
        context.watch<AuthProvider>().user?.id ?? '';
    final currency =
        context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final symbol = CurrencyFormatter.symbolFor(currency);

    if (wallet == null || provider.loading) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(backgroundColor: context.colors.bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Balances relevant to this wallet
    final netBalances = provider.myNetBalances;
    final relevantBalances = netBalances.values
        .where((e) => e.walletId == _id)
        .toList();

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, wallet)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                    child: _buildSummaryCard(wallet, symbol)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                    child: _buildInviteCard(context, wallet.inviteCode)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                    child: _buildBalancesSection(
                        context, relevantBalances, symbol,
                        provider: provider)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildExpensesHeader(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (wallet.transactions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'No expenses yet.',
                            style: GoogleFonts.inter(color: AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: wallet.transactions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 60),
                          itemBuilder: (_, i) {
                            final tx = wallet.transactions.reversed
                                .toList()[i];
                            return _TransactionRow(
                              tx: tx,
                              members: wallet.members,
                              myUserId: myUserId,
                              symbol: symbol,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () =>
                    context.push('/home/wallets/${widget.walletId}/add-expense'),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Add Expense',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WalletModel wallet) {
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
              wallet.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context, String inviteCode) {
    final shortCode = inviteCode.length > 13
        ? '${inviteCode.substring(0, 13)}…'
        : inviteCode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              child: const Icon(Icons.link_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite Members',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.text,
                    ),
                  ),
                  Text(
                    shortCode,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _copyInviteCode(context, inviteCode),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Copy Code',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _settle(NetEntry entry) async {
    final provider = context.read<WalletProvider>();
    final name = entry.member.name.isNotEmpty ? entry.member.name : 'this person';
    final iOwe = entry.amount < 0;
    final symbol = CurrencyFormatter.symbolFor(
        context.read<AuthProvider>().user?.preferredCurrency ?? 'USD');
    final amount = CurrencyFormatter.format(entry.amount.abs(), symbol: symbol);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Settle Up',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          iOwe
              ? 'Mark your $amount debt to $name as paid?'
              : 'Mark $name\'s $amount debt to you as settled?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Settle',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await provider.settleWith(entry);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              ok ? 'Settled!' : provider.error ?? 'Something went wrong',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyInviteCode(BuildContext context, String inviteCode) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Invite code copied!',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSummaryCard(WalletModel wallet, String symbol) {
    final spent = wallet.totalSpent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.balanceGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarRow(members: wallet.members),
                const Spacer(),
                Text(
                  '${wallet.memberCount} members',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TOTAL SPENT',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(spent, symbol: symbol),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesSection(
    BuildContext context,
    List<NetEntry> balances,
    String symbol, {
    required WalletProvider provider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Balances',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.text,
                    ),
                  ),
                  const Spacer(),
                  if (balances.isEmpty)
                    Text(
                      'All settled up!',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ),
            if (balances.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Text(
                  'No outstanding balances in this wallet.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.muted),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: balances.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 68),
                itemBuilder: (_, i) {
                  final e = balances[i];
                  final owedToMe = e.amount > 0;
                  final color =
                      owedToMe ? AppColors.success : AppColors.error;
                  final label = owedToMe ? 'owes you' : 'you owe';

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: e.member.color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              e.member.initials,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + direction label
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.member.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.text,
                                ),
                              ),
                              Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Amount badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${owedToMe ? '+' : '-'}${CurrencyFormatter.format(e.amount.abs(), symbol: symbol)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Settle button
                        GestureDetector(
                          onTap: () => _settle(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Settle',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Expenses',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.colors.text,
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.members});
  final List<WalletMember> members;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Row(
      children: visible
          .map(
            (m) => Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: m.color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5),
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
          )
          .toList(),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.tx,
    required this.members,
    required this.myUserId,
    required this.symbol,
  });

  final WalletTransaction tx;
  final List<WalletMember> members;
  final String myUserId;
  final String symbol;

  WalletMember? get _payer =>
      members.where((m) => m.userId == tx.payerUserId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final payer = _payer;
    final payerInitials = payer?.initials ??
        (tx.payerUserId.isNotEmpty ? tx.payerUserId[0].toUpperCase() : '?');
    final payerColor = payer?.color ?? const Color(0xFF3D7EFF);
    final payerName = tx.payerUserId == myUserId
        ? 'You'
        : (payer?.name.isNotEmpty == true ? payer!.name : tx.payerUserId);

    // My split share
    final mySplit = tx.splits
        .where((s) => s.userId == myUserId)
        .firstOrNull;
    final isMePayer = tx.payerUserId == myUserId;
    final myShareDisplay = isMePayer
        ? tx.price - (mySplit?.share ?? 0) // what others owe me
        : -(mySplit?.share ?? 0);           // what I owe

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: payerColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                payerInitials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: payerColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text,
                  ),
                ),
                Text(
                  '$payerName paid · ${DateFormatter.groupLabel(tx.date)}',
                  style:
                      GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(tx.price, symbol: symbol),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.text,
                ),
              ),
              if (mySplit != null || isMePayer)
                Text(
                  myShareDisplay >= 0
                      ? '+${CurrencyFormatter.format(myShareDisplay, symbol: symbol)}'
                      : '-${CurrencyFormatter.format(myShareDisplay.abs(), symbol: symbol)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: myShareDisplay >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
