// receipt_processing_loader.dart
//
// A self-contained, modern "processing receipt" loader for Flutter.
//
// Visual: an embossed dark-metallic-blue circular channel with a cluster of
// gold coins that roll around it with a weighty, accordion-like spring feel.
// Rotating status messages keep the user engaged, and it resolves into a
// gold ring + checkmark success state.
//
// Drop-in usage (auto demo loop — rolls, then shows success, then repeats):
//
//   const ReceiptProcessingLoader()
//
// Real usage — drive it from your own async work:
//
//   ReceiptProcessingLoader(
//     autoDemo: false,
//     success: _uploadDone,           // flip to true when processing finishes
//     successTitle: 'Receipt added',
//     successSubtitle: '\$24.80 · Groceries',
//     onCompleted: () => Navigator.pop(context),
//   )
//
// No third-party packages required.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ReceiptProcessingLoader extends StatefulWidget {
  const ReceiptProcessingLoader({
    super.key,
    this.title = 'Processing receipt',
    this.statuses = const ['Reading', 'Extracting', 'Categorizing'],
    this.success = false,
    this.autoDemo = true,
    this.demoProcessDuration = const Duration(milliseconds: 6200),
    this.successHold = const Duration(milliseconds: 1700),
    this.successTitle = 'Receipt added',
    this.successSubtitle = '\$24.80 · Groceries',
    this.onCompleted,
    this.size = 300,
    this.coinCount = 5,
  });

  /// Headline shown while processing.
  final String title;

  /// Status words cycled underneath the headline (~1.5s each).
  final List<String> statuses;

  /// Flip to `true` when your real work finishes to trigger the success state.
  /// Ignored when [autoDemo] is true.
  final bool success;

  /// When true the loader endlessly loops process → success → process so you
  /// can preview it. Set false in production and drive [success] yourself.
  final bool autoDemo;

  /// How long the demo "processing" phase lasts before auto-succeeding.
  final Duration demoProcessDuration;

  /// How long the success state is held before the demo loops again.
  final Duration successHold;

  final String successTitle;
  final String? successSubtitle;

  /// Called once when the success animation finishes (non-demo mode).
  final VoidCallback? onCompleted;

  /// Diameter of the animated dial in logical pixels.
  final double size;

  /// Number of coins in the rolling cluster.
  final int coinCount;

  @override
  State<ReceiptProcessingLoader> createState() =>
      _ReceiptProcessingLoaderState();
}

class _ReceiptProcessingLoaderState extends State<ReceiptProcessingLoader>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  // ---- choreography (time-delayed trajectories): the lead coin rolls off
  // first and each following coin starts a beat later, tracing the same eased
  // path. The lead completes a lap and stops at the top; the followers pile in
  // one-by-one and touch; then they all roll on again. Coins never disappear.
  // Direction: top, left -> right (clockwise).
  static const double _top = -math.pi / 2;
  static const double _gap = 0.47; // angular spacing when touching
  static const double _roll = 2.1; // seconds for the lead to complete one lap
  static const double _lag = 0.12; // delay between successive coins (s)
  static const double _holdTop = 0.45; // pause grouped at the top (s)
  late final double _tail = (widget.coinCount - 1) * _lag;
  late final double _cycleLen = _roll + _tail + _holdTop;
  // rolling: arc travelled / coin radius == constant ratio of the geometry.
  static const double _rollRatio = 100.0 / 23.0;

  // gentle ease (smoothstep): accelerate away, decelerate into the stop.
  static double _easeInOut(double p) => p * p * (3 - 2 * p);
  // lead's angle at local time tau (parked before start / after finish).
  double _headPath(double tau) {
    final u = (tau / _roll).clamp(0.0, 1.0);
    return _baseHead + math.pi * 2 * _easeInOut(u);
  }

  double _baseHead = _top; // lap start angle (advances +2pi each lap)
  double _cycleT = 0; // time within the current lap cycle
  double _globalMs = 0; // total processing time

  // ---- per-coin state ----
  late List<double> _ang;
  late List<double> _spin;
  late List<double> _alpha; // 1 while rolling; fades only on success

  // ---- timeline ----
  double _lastT = 0;
  double _successElapsed = 0; // seconds since success began
  _Phase _phase = _Phase.process;
  bool _completedCalled = false;

  // ---- display strings ----
  late String _title;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _resetCoins();
    _ticker = createTicker(_onTick)..start();
  }

  void _resetCoins() {
    final n = widget.coinCount;
    _baseHead = _top;
    _cycleT = 0;
    _globalMs = 0;
    _successElapsed = 0;
    _phase = _Phase.process;
    _completedCalled = false;
    _title = widget.title;
    _spin = List<double>.filled(n, 0);
    // grouped & touching at the top: lead at top, the rest trailing left
    _ang = List<double>.generate(n, (i) => _top - i * _gap);
    _alpha = List<double>.filled(n, 1);
  }

  // Advance to the next lap (continue rolling from the top).
  void _startCycle() {
    _cycleT = 0;
    _baseHead += math.pi * 2;
  }

  @override
  void didUpdateWidget(covariant ReceiptProcessingLoader old) {
    super.didUpdateWidget(old);
    // External trigger to finish (non-demo mode).
    if (!widget.autoDemo &&
        widget.success &&
        !old.success &&
        _phase == _Phase.process) {
      _beginSuccess();
    }
  }

  void _beginSuccess() {
    _phase = _Phase.success;
    _successElapsed = 0;
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    double dt = t - _lastT;
    _lastT = t;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30; // clamp after stalls

    if (_phase == _Phase.process) {
      _cycleT += dt;
      _globalMs += dt * 1000;

      // Each coin follows the lead's eased path, delayed by i*_lag and trailing
      // by i*_gap: first goes first, the rest follow one-by-one, then pile in
      // and touch at the top.
      for (int i = 0; i < _ang.length; i++) {
        final prev = _ang[i];
        _ang[i] = _headPath(_cycleT - i * _lag) - i * _gap;
        _spin[i] += (_ang[i] - prev) * _rollRatio; // rolling
      }

      // Rotating status text.
      final idx = (_globalMs / 1500).floor() % widget.statuses.length;
      final dots = 1 + ((_globalMs / 400).floor() % 3);
      final next = '${widget.statuses[idx]}${'.' * dots}';
      if (next != _status) setState(() => _status = next);

      // End of a lap (rolled + paused): finish (gold success) or roll again.
      if (_cycleT >= _cycleLen) {
        final shouldFinish = widget.autoDemo
            ? _globalMs >= widget.demoProcessDuration.inMilliseconds
            : widget.success;
        if (shouldFinish) {
          _beginSuccess();
        } else {
          _startCycle();
        }
      }
    } else {
      _successElapsed += dt;
      if (_title != widget.successTitle) {
        setState(() => _title = widget.successTitle);
      }
      // success reveal lasts ~0.9s
      if (_successElapsed >= 0.9 && !_completedCalled) {
        _completedCalled = true;
        widget.onCompleted?.call();
      }
      if (widget.autoDemo &&
          _successElapsed >=
              0.9 + widget.successHold.inMilliseconds / 1000) {
        setState(_resetCoins);
        _status = '';
      }
    }

    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inSuccess = _phase == _Phase.success;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.42),
          radius: 1.05,
          colors: [Color(0xFF20304F), Color(0xFF131F36), Color(0xFF070B14)],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _LoaderPainter(
                  repaint: _repaint,
                  ang: _ang,
                  spin: _spin,
                  alpha: _alpha,
                  phase: _phase,
                  successP: (_successElapsed / 0.9).clamp(0.0, 1.0),
                  coinCount: widget.coinCount,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              _title,
              style: const TextStyle(
                color: Color(0xFFE9EEF8),
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 18,
              child: inSuccess
                  ? (widget.successSubtitle == null
                      ? const SizedBox.shrink()
                      : Text(
                          widget.successSubtitle!,
                          style: const TextStyle(
                            color: Color(0xFFCBA85A),
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ))
                  : Text(
                      _status,
                      style: const TextStyle(
                        color: Color(0xFFC79A4F),
                        fontSize: 13.5,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Phase { process, success }

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({
    required Listenable repaint,
    required this.ang,
    required this.spin,
    required this.alpha,
    required this.phase,
    required this.successP,
    required this.coinCount,
  }) : super(repaint: repaint);

  final List<double> ang;
  final List<double> spin;
  final List<double> alpha;
  final _Phase phase;
  final double successP;
  final int coinCount;

  // Everything is designed in a 300x300 space and scaled to fit.
  static const double _u = 300;
  static const double cx = 150, cy = 150;
  static const double R = 100, W = 60, CR = 23;
  static const double outerR = R + W / 2; // 130
  static const double innerR = R - W / 2; // 70

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _u, size.height / _u);

    _backplate(canvas);
    _track(canvas);

    if (phase == _Phase.process) {
      for (int i = 0; i < ang.length; i++) {
        if (alpha[i] <= 0) continue; // not released yet
        _coin(canvas, ang[i], spin[i], alpha[i].clamp(0.0, 1.0));
      }
    } else {
      final coinAlpha = (1 - successP * 1.6).clamp(0.0, 1.0);
      if (coinAlpha > 0) {
        for (int i = 0; i < ang.length; i++) {
          _coin(canvas, ang[i], spin[i], coinAlpha * alpha[i].clamp(0.0, 1.0));
        }
      }
      _success(canvas, successP);
    }

    canvas.restore();
  }

  // ---------- background pooled glow ----------
  void _backplate(Canvas canvas) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(cx, cy - 18),
        150,
        const [
          Color(0x803A5CAA), // rgba(58,92,170,.50)
          Color(0x4D1E3050),
          Color(0x00000000),
        ],
        const [0.0, 0.7, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, _u, _u), paint);
  }

  // ---------- embossed metallic-blue channel ----------
  void _track(Canvas canvas) {
    const center = Offset(cx, cy);

    // raised outer lip (light from the top)
    final lip = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, cy - outerR),
        const Offset(0, cy + outerR),
        const [Color(0xFF34486A), Color(0xFF1D2C47), Color(0xFF0B1322)],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, outerR + 7, lip);

    // concave channel: annulus clip + vertical shading
    final ann = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: outerR))
      ..addOval(Rect.fromCircle(center: center, radius: innerR));
    canvas.save();
    canvas.clipPath(ann);
    final ch = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, cy - outerR),
        const Offset(0, cy + outerR),
        const [
          Color(0xFF070B14),
          Color(0xFF16243F),
          Color(0xFF243A5E),
          Color(0xFF0B1322),
        ],
        const [0.0, 0.28, 0.62, 1.0],
      );
    canvas.drawRect(
      Rect.fromCircle(center: center, radius: outerR),
      ch,
    );
    canvas.restore();

    // rim definition
    canvas.drawCircle(
      center,
      innerR + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x14A0C6FF),
    );
    canvas.drawCircle(
      center,
      outerR - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x66000000),
    );

    // raised inner disc + soft contact shadow
    canvas.drawCircle(
      const Offset(cx, cy - 2),
      innerR,
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final disc = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(cx, cy - innerR * 0.4),
        innerR * 1.15,
        const [Color(0xFF22344F), Color(0xFF15233B), Color(0xFF0A1120)],
        const [0.0, 0.7, 1.0],
      );
    canvas.drawCircle(center, innerR, disc);
  }

  // ---------- a single rolling gold coin ----------
  void _coin(Canvas canvas, double a, double spinAngle, double alpha) {
    final x = cx + math.cos(a) * R;
    final y = cy + math.sin(a) * R;

    // contact shadow in the channel
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x, y + CR * 0.55), width: CR * 1.9, height: CR * 0.84),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.38 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.save();
    canvas.translate(x, y);
    // alpha for fade-out at success — layer everything through one alpha.
    if (alpha < 1) {
      canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: CR + 6),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
      );
    }

    // coin thickness (rim crescent beneath the face)
    canvas.drawCircle(
        const Offset(0, 2.4), CR, Paint()..color = const Color(0xFF8A5E22));

    // coin face
    final face = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(-CR * 0.4, -CR * 0.46),
        CR * 1.15,
        const [
          Color(0xFFFFEEBB),
          Color(0xFFF1C861),
          Color(0xFFDCA23A),
          Color(0xFFA9762A),
        ],
        const [0.0, 0.34, 0.72, 1.0],
      );
    canvas.drawCircle(Offset.zero, CR, face);

    // milled / reeded edge — rotates with travel to read as rolling
    canvas.save();
    canvas.rotate(spinAngle);
    const teeth = 32;
    final reedLight = Paint()
      ..strokeWidth = 1.3
      ..color = const Color(0x52FFEEBE);
    final reedDark = Paint()
      ..strokeWidth = 1.3
      ..color = const Color(0x80785019);
    for (int j = 0; j < teeth; j++) {
      final aa = j / teeth * math.pi * 2;
      final ca = math.cos(aa), sa = math.sin(aa);
      canvas.drawLine(
        Offset(ca * (CR - 0.6), sa * (CR - 0.6)),
        Offset(ca * (CR - 3.4), sa * (CR - 3.4)),
        j.isOdd ? reedDark : reedLight,
      );
    }
    canvas.restore();

    // medallion rings
    canvas.drawCircle(
      Offset.zero,
      CR * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0x6B78501A),
    );
    canvas.drawCircle(
      Offset.zero,
      CR * 0.62 - 1.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x38FFF2CD),
    );

    // soft specular highlight (fixed top-left light)
    canvas.drawCircle(
      Offset.zero,
      CR,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          const Offset(-CR * 0.34, -CR * 0.4),
          CR * 0.9,
          const [Color(0x8CFFFFFF), Color(0x1FFFFAE6), Color(0x00FFFFFF)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // crisp rim: bright top-left, dark bottom-right
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: CR - 0.8),
      math.pi * 0.9,
      math.pi * 0.85,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x80FFF0C3),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: CR - 0.8),
      -math.pi * 0.1,
      math.pi * 0.85,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x805A3A12),
    );

    if (alpha < 1) canvas.restore(); // saveLayer
    canvas.restore();
  }

  // ---------- gold ring + checkmark success ----------
  void _success(Canvas canvas, double p) {
    const center = Offset(cx, cy);

    // gold ring sweep
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = W * 0.5
      ..shader = ui.Gradient.linear(
        const Offset(cx - R, cy - R),
        const Offset(cx + R, cy + R),
        const [Color(0xFFF4CF72), Color(0xFFD49A36)],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: R),
      -math.pi / 2,
      math.pi * 2 * (p * 1.2).clamp(0.0, 1.0),
      false,
      ring..color = ring.color.withOpacity((p * 1.4).clamp(0.0, 1.0)),
    );

    // checkmark
    final ck = ((p - 0.45) / 0.55).clamp(0.0, 1.0);
    if (ck <= 0) return;
    canvas.save();
    canvas.translate(cx, cy);
    final p1 = const Offset(-26, 2);
    final p2 = const Offset(-7, 22);
    final p3 = const Offset(30, -22);
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (ck <= 0.5) {
      final k = ck / 0.5;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * k, p1.dy + (p2.dy - p1.dy) * k);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final k = (ck - 0.5) / 0.5;
      path.lineTo(p2.dx + (p3.dx - p2.dx) * k, p2.dy + (p3.dy - p2.dy) * k);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFF7E6BF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter old) => true;
}

// ---------------------------------------------------------------------------
// Optional: a runnable demo. Delete this if you only need the widget above.
// ---------------------------------------------------------------------------
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFF05080F),
      body: Center(
        child: SizedBox(
          width: 360,
          height: 480,
          child: ReceiptProcessingLoader(),
        ),
      ),
    ),
  ));
}
