import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  bool _processing = false;
  final _picker = ImagePicker();

  Future<void> _capture({bool fromGallery = false}) async {
    final file = await _picker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _processing = true);

    try {
      final dio = ApiClient.instance;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path,
            filename: file.name),
      });
      final res = await dio.post(
        ApiEndpoints.transactionReceipt,
        data: formData,
      );
      final responseBody = res.data as Map<String, dynamic>;
      final txData = responseBody['transaction'] as Map<String, dynamic>;
      final locData = responseBody['location'] as Map<String, dynamic>?;

      final data = res.data as Map<String, dynamic>;
      final catProvider = context.read<TransactionProvider>();
      final catId = data['category_id'] as int?;
      final catName = catProvider.categories
          .firstWhere(
            (c) => c.id == catId,
            orElse: () => CategoryModel(id: 0, name: 'Other'),
          )
          .name;

      final tx = TransactionModel(
        id: 0,
        title: txData['title'] ?? '',
        price: (txData['price'] as num?)?.toDouble() ?? 0,
        dateMade: DateTime.now(),
        categoryId: catId,
        categoryName: catName,
        type: txData['type'] ?? 'Expense',
      );

      if (mounted) {
        setState(() => _processing = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(initial: tx, initialLocation: locData),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: SafeArea(
        child: Stack(
          children: [
            // Radial gradient overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [
                      Color(0x333D7EFF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // Status-bar style header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Scan Receipt',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),

                // Camera frame
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          children: [
                            // Frame border
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            // Corner brackets
                            ..._corners(),
                            // Center content
                            if (_processing)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            else
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      size: 44,
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Point at your receipt',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(40, 24, 40, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery button
                      GestureDetector(
                        onTap: () => _capture(fromGallery: true),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),

                      // Main capture button
                      GestureDetector(
                        onTap: _processing ? null : () => _capture(),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      ),

                      // Search / flashlight placeholder
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_auto_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const size = 24.0;
    const thickness = 2.5;
    const radius = 8.0;
    const color = Colors.white;
    const inset = 12.0;

    Widget corner({
      required AlignmentGeometry alignment,
      required BorderRadius borderRadius,
    }) {
      return Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerPainter(
                borderRadius: borderRadius,
                color: color,
                thickness: thickness,
              ),
            ),
          ),
        ),
      );
    }

    return [
      corner(
        alignment: Alignment.topLeft,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(radius)),
      ),
      corner(
        alignment: Alignment.topRight,
        borderRadius:
            const BorderRadius.only(topRight: Radius.circular(radius)),
      ),
      corner(
        alignment: Alignment.bottomLeft,
        borderRadius:
            const BorderRadius.only(bottomLeft: Radius.circular(radius)),
      ),
      corner(
        alignment: Alignment.bottomRight,
        borderRadius:
            const BorderRadius.only(bottomRight: Radius.circular(radius)),
      ),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.borderRadius,
    required this.color,
    required this.thickness,
  });

  final BorderRadius borderRadius;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        topLeft: borderRadius.topLeft,
        topRight: borderRadius.topRight,
        bottomLeft: borderRadius.bottomLeft,
        bottomRight: borderRadius.bottomRight,
      ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
