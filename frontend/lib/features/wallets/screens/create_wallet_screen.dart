import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _memberNames = [];

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty || _memberNames.contains(name)) return;
    setState(() {
      _memberNames.add(name);
      _memberController.clear();
    });
  }

  void _removeMember(String name) {
    setState(() => _memberNames.remove(name));
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final goal = double.tryParse(_goalController.text);
    final members = [
      kMockMe,
      ..._memberNames.map((n) => WalletMember(
            name: n,
            color: _memberColor(_memberNames.indexOf(n)),
          )),
    ];

    context.read<WalletProvider>().addWallet(
          name: name,
          monthlyGoal: goal,
          members: members,
        );
    context.pop();
  }

  Color _memberColor(int index) {
    const colors = [
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFF97316),
      Color(0xFFEC4899),
      Color(0xFF0EA5E9),
    ];
    return colors[index % colors.length];
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
                    _sectionLabel('WALLET NAME'),
                    const SizedBox(height: 6),
                    _buildInput(
                      controller: _nameController,
                      hint: 'e.g. Apartment, Road Trip',
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('MONTHLY GOAL (OPTIONAL)'),
                    const SizedBox(height: 6),
                    _buildInput(
                      controller: _goalController,
                      hint: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 6),
                        child: Text('\$',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('INVITE MEMBERS'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput(
                            controller: _memberController,
                            hint: 'Enter name',
                            onSubmitted: (_) => _addMember(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addMember,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_add_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    if (_memberNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MemberChip(
                            name: kMockMe.name,
                            color: kMockMe.color,
                            isMe: true,
                          ),
                          ..._memberNames.asMap().entries.map(
                                (e) => _MemberChip(
                                  name: e.value,
                                  color: _memberColor(e.key),
                                  onRemove: () => _removeMember(e.value),
                                ),
                              ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      _MemberChip(
                          name: kMockMe.name,
                          color: kMockMe.color,
                          isMe: true),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _create,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Create Wallet',
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
            'New Wallet',
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

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    Widget? prefix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.name,
    required this.color,
    this.isMe = false,
    this.onRemove,
  });
  final String name;
  final Color color;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isMe ? '$name (you)' : name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
