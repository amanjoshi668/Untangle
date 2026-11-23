import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../untangle_theme.dart';

enum CharacterMood {
  thinking,
  aha,
  tugOfWar,
  flowCalm,
  flowStressed,
  flowBored,
  exploring,
  celebrating,
}

/// "Kip" — Untangle's minimalist hand-drawn ink & gold companion character,
/// inspired by the stick-figure thinkers in The Decision Book.
/// Uses finite spring animations (and tap-to-bounce!) so it stays lively and
/// 100% compatible with widget test pumpAndSettle().
class UntangleCharacter extends StatefulWidget {
  final CharacterMood mood;
  final double size;
  final double tilt; // -1.0 (pulled left) to +1.0 (pulled right)
  final Color? inkColor;
  final Color? accentColor;
  final bool interactive;

  const UntangleCharacter({
    super.key,
    required this.mood,
    this.size = 64,
    this.tilt = 0.0,
    this.inkColor,
    this.accentColor,
    this.interactive = true,
  });

  @override
  State<UntangleCharacter> createState() => _UntangleCharacterState();
}

class _UntangleCharacterState extends State<UntangleCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;
  int _waveSeed = 0;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _bounceAnim = CurvedAnimation(
      parent: _bounceCtrl,
      curve: Curves.elasticOut,
    );
    _bounceCtrl.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant UntangleCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _bounceCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _triggerWave() {
    if (!widget.interactive) return;
    setState(() => _waveSeed++);
    _bounceCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ink = widget.inkColor ?? cs.onSurface;
    final accent = widget.accentColor ?? cs.primary;

    final canvas = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.tilt.clamp(-1.0, 1.0)),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (ctx, animatedTilt, _) {
        return AnimatedBuilder(
          animation: _bounceAnim,
          builder: (_, __) {
            final pop = 0.88 + (_bounceAnim.value * 0.12);
            final hopY = -math.sin(_bounceAnim.value * math.pi) * 4.5;
            return Transform.translate(
              offset: Offset(0, hopY),
              child: Transform.scale(
                scale: pop,
                child: CustomPaint(
                  size: Size(
                    widget.mood == CharacterMood.tugOfWar ? widget.size * 2.2 : widget.size,
                    widget.size,
                  ),
                  painter: _KipPainter(
                    mood: widget.mood,
                    tilt: animatedTilt,
                    progress: _bounceAnim.value,
                    waveToggle: _waveSeed.isOdd,
                    ink: ink,
                    accent: accent,
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!widget.interactive) return canvas;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _triggerWave,
      child: Tooltip(
        message: 'Tap Kip',
        child: canvas,
      ),
    );
  }
}

class _KipPainter extends CustomPainter {
  final CharacterMood mood;
  final double tilt;
  final double progress;
  final bool waveToggle;
  final Color ink;
  final Color accent;

  const _KipPainter({
    required this.mood,
    required this.tilt,
    required this.progress,
    required this.waveToggle,
    required this.ink,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2 + (mood == CharacterMood.tugOfWar ? tilt * (w * 0.14) : 0);

    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (h * 0.042).clamp(1.8, 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentStroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = (h * 0.042).clamp(1.8, 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentFill = Paint()..color = accent.withOpacity(0.20);

    // Elastic rubber bands behind Kip in tugOfWar mode
    if (mood == CharacterMood.tugOfWar) {
      final waistY = h * 0.62;
      final leftPost = Offset(w * 0.08, waistY);
      final rightPost = Offset(w * 0.92, waistY);
      // Posts
      canvas.drawLine(Offset(leftPost.dx, h * 0.44), Offset(leftPost.dx, h * 0.82), stroke);
      canvas.drawLine(Offset(rightPost.dx, h * 0.44), Offset(rightPost.dx, h * 0.82), stroke);
      // Left band (Holding)
      final leftBand = Paint()
        ..color = ink.withOpacity(0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 + (-tilt).clamp(0, 1) * 1.6)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftPost, Offset(cx - h * 0.04, waistY), leftBand);
      // Right band (Pulling)
      final rightBand = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 + tilt.clamp(0, 1) * 1.6)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx + h * 0.04, waistY), rightPost, rightBand);
    }

    // Soft gold halo/accent backdrop behind head for warmth
    final headR = h * 0.165;
    final headCenter = Offset(cx + tilt * (h * 0.09), h * 0.36);
    canvas.drawCircle(headCenter, headR * 1.18, accentFill);

    // Head
    canvas.drawCircle(headCenter, headR, stroke);

    // Eyes & expression
    final eyePaint = Paint()..color = ink;
    final eyeY = headCenter.dy - headR * 0.10;
    final eyeDx = headR * 0.34;
    if (mood == CharacterMood.flowBored) {
      // Half-closed sleepy eyes
      canvas.drawLine(Offset(headCenter.dx - eyeDx - 2, eyeY), Offset(headCenter.dx - eyeDx + 2, eyeY), stroke);
      canvas.drawLine(Offset(headCenter.dx + eyeDx - 2, eyeY), Offset(headCenter.dx + eyeDx + 2, eyeY), stroke);
    } else {
      canvas.drawCircle(Offset(headCenter.dx - eyeDx, eyeY), (h * 0.022).clamp(1.2, 2.2), eyePaint);
      canvas.drawCircle(Offset(headCenter.dx + eyeDx, eyeY), (h * 0.022).clamp(1.2, 2.2), eyePaint);
    }

    // Mouth
    final mouthRect = Rect.fromCenter(
      center: Offset(headCenter.dx, headCenter.dy + headR * 0.25),
      width: headR * 0.65,
      height: headR * 0.42,
    );
    if (mood == CharacterMood.flowStressed) {
      // Wavy nervous mouth
      canvas.drawArc(mouthRect.shift(Offset(0, headR * 0.15)), math.pi * 1.15, math.pi * 0.7, false, stroke);
    } else if (mood == CharacterMood.thinking || mood == CharacterMood.flowBored) {
      // Small thoughtful line
      canvas.drawLine(
        Offset(headCenter.dx - headR * 0.22, headCenter.dy + headR * 0.34),
        Offset(headCenter.dx + headR * 0.22, headCenter.dy + headR * 0.30),
        stroke,
      );
    } else {
      // Warm smile
      canvas.drawArc(mouthRect, 0.15 * math.pi, 0.7 * math.pi, false, stroke);
    }

    // Torso
    final neck = Offset(headCenter.dx, headCenter.dy + headR);
    final hip = Offset(cx, h * 0.72);
    canvas.drawLine(neck, hip, stroke);

    // Legs
    final legSpread = mood == CharacterMood.celebrating ? h * 0.19 : h * 0.14;
    canvas.drawLine(hip, Offset(hip.dx - legSpread, h * 0.92), stroke);
    canvas.drawLine(hip, Offset(hip.dx + legSpread, h * 0.92), stroke);

    // Arms & Mood Props
    final shoulder = Offset(
      neck.dx + (hip.dx - neck.dx) * 0.28,
      neck.dy + (hip.dy - neck.dy) * 0.28,
    );

    switch (mood) {
      case CharacterMood.thinking:
        // Left hand on hip, right hand touching chin
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.14, shoulder.dy + h * 0.12), stroke);
        canvas.drawLine(shoulder, Offset(headCenter.dx + headR * 0.75, headCenter.dy + headR * 0.7), stroke);
        // Floating golden thought dots & mini-knot
        final d1 = Offset(headCenter.dx + headR * 1.15, headCenter.dy - headR * 0.95);
        canvas.drawCircle(d1, h * 0.032, Paint()..color = accent);
        canvas.drawCircle(Offset(d1.dx + h * 0.08, d1.dy - h * 0.09), h * 0.048, accentStroke);
        break;

      case CharacterMood.aha:
        // Raised excited hand + glowing lightbulb rays above head
        final armLift = waveToggle ? h * 0.24 : h * 0.20;
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.14, shoulder.dy + h * 0.10), stroke);
        canvas.drawLine(shoulder, Offset(shoulder.dx + h * 0.18, shoulder.dy - armLift), stroke);
        _drawSparkleRays(canvas, Offset(headCenter.dx, headCenter.dy - headR * 1.55), h * 0.10, accentStroke);
        break;

      case CharacterMood.tugOfWar:
        // Arms gripping waist / balancing against the pull
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.16, h * 0.62), stroke);
        canvas.drawLine(shoulder, Offset(shoulder.dx + h * 0.16, h * 0.62), stroke);
        break;

      case CharacterMood.flowCalm:
        // Serene open arms + gentle flow wave underneath
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.20, shoulder.dy - h * 0.04), stroke);
        canvas.drawLine(shoulder, Offset(shoulder.dx + h * 0.20, shoulder.dy - h * 0.04), stroke);
        final wave = Path()
          ..moveTo(w * 0.14, h * 0.94)
          ..quadraticBezierTo(w * 0.35, h * 0.86, w * 0.50, h * 0.94)
          ..quadraticBezierTo(w * 0.65, h * 1.00, w * 0.86, h * 0.92);
        canvas.drawPath(wave, accentStroke);
        break;

      case CharacterMood.flowStressed:
        // Hands raised by head + sweat drop
        canvas.drawLine(shoulder, Offset(headCenter.dx - headR * 1.1, headCenter.dy), stroke);
        canvas.drawLine(shoulder, Offset(headCenter.dx + headR * 1.1, headCenter.dy), stroke);
        canvas.drawCircle(Offset(headCenter.dx + headR * 1.2, headCenter.dy - headR * 0.6), h * 0.035, Paint()..color = accent);
        break;

      case CharacterMood.flowBored:
        // Drooping arms + tiny "z"
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.12, shoulder.dy + h * 0.18), stroke);
        canvas.drawLine(shoulder, Offset(shoulder.dx + h * 0.12, shoulder.dy + h * 0.18), stroke);
        final zx = headCenter.dx + headR * 1.1;
        final zy = headCenter.dy - headR * 0.9;
        final zPath = Path()
          ..moveTo(zx, zy)
          ..lineTo(zx + h * 0.09, zy)
          ..lineTo(zx, zy + h * 0.09)
          ..lineTo(zx + h * 0.09, zy + h * 0.09);
        canvas.drawPath(zPath, accentStroke);
        break;

      case CharacterMood.exploring:
        // One arm pointing forward with a golden compass ring
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.14, shoulder.dy + h * 0.12), stroke);
        final hand = Offset(shoulder.dx + h * 0.20, shoulder.dy - h * 0.04);
        canvas.drawLine(shoulder, hand, stroke);
        canvas.drawCircle(Offset(hand.dx + h * 0.05, hand.dy - h * 0.04), h * 0.07, accentStroke);
        break;

      case CharacterMood.celebrating:
        // Both arms high in V + celebratory sparkles
        canvas.drawLine(shoulder, Offset(shoulder.dx - h * 0.20, shoulder.dy - h * 0.22), stroke);
        canvas.drawLine(shoulder, Offset(shoulder.dx + h * 0.20, shoulder.dy - h * 0.22), stroke);
        _drawSparkleRays(canvas, Offset(headCenter.dx - headR * 1.5, headCenter.dy - headR * 1.1), h * 0.08, accentStroke);
        _drawSparkleRays(canvas, Offset(headCenter.dx + headR * 1.5, headCenter.dy - headR * 1.1), h * 0.08, accentStroke);
        break;
    }
  }

  void _drawSparkleRays(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), p);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
  }

  @override
  bool shouldRepaint(covariant _KipPainter old) =>
      old.mood != mood ||
      old.tilt != tilt ||
      old.progress != progress ||
      old.waveToggle != waveToggle ||
      old.ink != ink ||
      old.accent != accent;
}

/// Subtle tactile press bounce wrapper for cards & interactive controls.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Smooth finite entrance glide + fade for cards and sections.
class EntranceSlide extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const EntranceSlide({
    super.key,
    required this.child,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (ctx, val, ch) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * 10),
            child: ch,
          ),
        );
      },
      child: child,
    );
  }
}

/// Shows a quick, joyful Kip celebration banner when saving a decision.
void showUntangleCelebration(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: UntangleTheme.heroStart,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          const UntangleCharacter(
            mood: CharacterMood.celebrating,
            size: 34,
            inkColor: UntangleTheme.paper,
            accentColor: UntangleTheme.goldDark,
            interactive: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: UntangleTheme.paper, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}
