import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/exchange_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/category_dot.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.initial, this.initialLocation});

  /// If set, the screen is in edit mode.
  final TransactionModel? initial;
  final Map<String, dynamic>? initialLocation;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late String _type;
  String _amount = '0';
  int? _selectedCategoryId;
  String? _selectedCategoryName;

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  // Location Controllers & State
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  double? _lat;
  double? _lng;
  bool _saving = false;

  void _selectCategory(CategoryModel cat) {
    setState(() {
      _selectedCategoryId = cat.id;
      _selectedCategoryName = cat.name;
    });
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.initial;
    if (tx != null) {
      _type = tx.type;
      _amount = tx.price.toStringAsFixed(2);
      _selectedCategoryId = tx.categoryId;
      _selectedCategoryName = tx.categoryName;
      _titleController.text = tx.title;
    } else {
      _type = 'Expense';
    }

    // Initialize location variables if passed from receipt scan
    if (widget.initialLocation != null) {
      _addressController.text = widget.initialLocation!['address'] ?? '';
      _cityController.text = widget.initialLocation!['city'] ?? '';
      _lat = (widget.initialLocation!['lat'] as num?)?.toDouble();
      _lng = (widget.initialLocation!['lng'] as num?)?.toDouble();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<TransactionProvider>();
      await provider.loadCategories();
      if (mounted && _selectedCategoryId == null && provider.categories.isNotEmpty) {
        _selectCategory(provider.categories.first);
      }

      final tx = widget.initial;
      if (tx != null && mounted) {
        final svc = context.read<ExchangeRateService>();
        final currency = context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
        await svc.prefetchRate(currency);
        if (mounted) {
          setState(() {
            _amount = svc.convertFromMkd(tx.price, currency).toStringAsFixed(2);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : '0';
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount == '0') {
          _amount = key;
        } else {
          if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
          _amount += key;
        }
      }
    });
  }

  // Opens the bottom sheet banner displaying OpenStreetMap view
  void _showLocationBanner() {
    if (_lat == null || _lng == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Merchant Location',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.text,
                  ),
                ),
                const SizedBox(height: 16),

                // Live interactive Map View using OpenStreetMap (Free)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_lat!, _lng!),
                        initialZoom: 15.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.smartspend.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_lat!, _lng!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Editable Fields inside the banner
                TextField(
                  controller: _addressController,
                  style: GoogleFonts.inter(fontSize: 14, color: context.colors.text),
                  decoration: InputDecoration(
                    labelText: 'Address',
                    labelStyle: GoogleFonts.inter(color: AppColors.muted),
                    filled: true,
                    fillColor: context.colors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  style: GoogleFonts.inter(fontSize: 14, color: context.colors.text),
                  decoration: InputDecoration(
                    labelText: 'City',
                    labelStyle: GoogleFonts.inter(color: AppColors.muted),
                    filled: true,
                    fillColor: context.colors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_amount) ?? 0;
    if (price <= 0) return;

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();

    final title = _titleController.text.trim().isEmpty
        ? (_selectedCategoryName ?? 'Transaction')
        : _titleController.text.trim();

    final currency = context.read<AuthProvider>().user?.preferredCurrency ?? 'USD';
    final mkdPrice = await context.read<ExchangeRateService>().exchangeForDbStore(price, currency);

    // Collect Location info if captured
    Map<String, dynamic>? finalLocation;
    if (_lat != null && _lng != null) {
      finalLocation = {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'lat': _lat,
        'lng': _lng,
      };
    }

    bool ok;
    if (widget.initial != null && widget.initial!.id > 0) {
      ok = await provider.update(TransactionModel(
        id: widget.initial!.id,
        title: title,
        price: mkdPrice,
        dateMade: widget.initial!.dateMade,
        categoryId: _selectedCategoryId,
        categoryName: _selectedCategoryName ?? 'Other',
        type: _type,
      ));
    } else {
      // This is a brand new insert (from the OCR scan), so it safely routes here!
      ok = await provider.add(
        title: title,
        price: mkdPrice,
        type: _type,
        categoryId: _selectedCategoryId,
        dateMade: DateTime.now(),
        location: finalLocation, // Sends the location payload to the backend
      );
    }

    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      context.read<AuthProvider>().refreshBalances();
      context.pop();
    } else {
      final err = context.read<TransactionProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to save transaction. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildTypeToggle(),
                    const SizedBox(height: 16),
                    _buildTitleInput(),
                    const SizedBox(height: 16),

                    // NEW: Dynamic Location Banner Trigger Button
                    if (_lat != null && _lng != null) _buildLocationTriggerTile(),

                    const SizedBox(height: 24),
                    _buildAmountDisplay(),
                    const SizedBox(height: 24),
                    _buildNumberPad(),
                    const SizedBox(height: 24),

                    if (_type == 'Expense') ...[
                      _buildCategoryLabel(),
                      const SizedBox(height: 10),
                      _buildCategoryGrid(),
                      const SizedBox(height: 20),
                    ],

                    _buildNoteInput(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTriggerTile() {
    return GestureDetector(
      onTap: _showLocationBanner,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merchant Location Verified',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.text),
                  ),
                  Text(
                    _addressController.text.isNotEmpty ? _addressController.text : 'Tap to view map & edit info',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              child: Icon(Icons.close_rounded,
                  size: 18, color: context.colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.initial != null ? 'Edit Transaction' : 'Add Transaction',
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

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: ['Expense', 'Income'].map((t) {
          final active = _type == t;
          final activeColor =
              t == 'Expense' ? AppColors.error : AppColors.success;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _type = t);
                final cats = context.read<TransactionProvider>().categories;
                if (t == 'Income') {
                  setState(() {
                    _selectedCategoryId = null;
                    _selectedCategoryName = null;
                  });
                } else {
                  final cats = context.read<TransactionProvider>().categories;
                  if (cats.isNotEmpty) {
                    _selectCategory(cats.first);
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final symbol = CurrencyFormatter.symbolFor(
        context.watch<AuthProvider>().user?.preferredCurrency ?? 'USD');
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              symbol,
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _amount,
            style: GoogleFonts.inter(
              fontSize: 60,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _NumKey(label: key, onTap: () => _onKey(key)),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryLabel() {
    return Text(
      'CATEGORY',
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = context.watch<TransactionProvider>().categories;

    if (categories.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: categories.map((cat) {
        final selected = _selectedCategoryId == cat.id;
        return GestureDetector(
          onTap: () => _selectCategory(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected ? context.colors.secondaryBg : context.colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : context.colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CategoryDot(category: cat.name, size: 36),
                const SizedBox(height: 4),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.darkText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }).toList(),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TITLE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          style: GoogleFonts.inter(fontSize: 14, color: context.colors.text),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Title (e.g. Grocery run, Netflix...)',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
            filled: true,
            fillColor: context.colors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      style: GoogleFonts.inter(fontSize: 14, color: context.colors.text),
      decoration: InputDecoration(
        hintText: 'Add a note...',
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
        filled: true,
        fillColor: context.colors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                widget.initial != null
                    ? 'Update Transaction'
                    : 'Save Transaction',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _NumKey extends StatefulWidget {
  const _NumKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

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
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 56,
        decoration: BoxDecoration(
          color: _pressed ? context.colors.secondaryBg : context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: widget.label == '⌫'
              ? Icon(Icons.backspace_outlined,
                  size: 20, color: context.colors.text)
              : Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text,
                  ),
                ),
        ),
      ),
    );
  }
}
