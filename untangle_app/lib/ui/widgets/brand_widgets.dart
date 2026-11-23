import 'package:flutter/material.dart';
import '../../models/decision_model.dart';
import '../untangle_theme.dart';

/// The Untangle brand mark: a loose loop resolving into a straight arrow.
class KnotMark extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const KnotMark({
    super.key,
    this.size = 20,
    required this.color,
    this.strokeWidth = 2.4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.6, size),
      painter: _KnotPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _KnotPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _KnotPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final loop = Path()
      ..moveTo(w * 0.06, h * 0.70)
      ..cubicTo(w * 0.00, h * 0.18, w * 0.40, h * 0.02, w * 0.42, h * 0.42)
      ..cubicTo(w * 0.44, h * 0.86, w * 0.14, h * 0.82, w * 0.24, h * 0.46)
      ..cubicTo(w * 0.32, h * 0.22, w * 0.50, h * 0.50, w * 0.58, h * 0.50)
      ..lineTo(w * 0.94, h * 0.50);
    canvas.drawPath(loop, paint);

    final head = Path()
      ..moveTo(w * 0.83, h * 0.32)
      ..lineTo(w * 0.94, h * 0.50)
      ..lineTo(w * 0.83, h * 0.68);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant _KnotPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// Numbered tile tinted in the technique's book-section color.
class SectionMonogram extends StatelessWidget {
  final DecisionModelSpec spec;
  final double size;

  const SectionMonogram({super.key, required this.spec, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final c = UntangleTheme.sectionColor(spec.section, b);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withOpacity(b == Brightness.dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        spec.id.toString().padLeft(2, '0'),
        style: TextStyle(
          fontFamily: UntangleTheme.displayFamily,
          fontWeight: FontWeight.w700,
          fontSize: (size * 0.38).clamp(12.0, 22.0),
          color: c,
        ),
      ),
    );
  }
}

class EngineMeta {
  static IconData icon(CanvasEngine e) {
    switch (e) {
      case CanvasEngine.e1Quadrant:
        return Icons.grid_view_rounded;
      case CanvasEngine.e2Force:
        return Icons.balance;
      case CanvasEngine.e3SlidersSvg:
        return Icons.radar;
      case CanvasEngine.e4Diagnostic:
        return Icons.checklist_rounded;
      case CanvasEngine.e5Combinator:
        return Icons.tips_and_updates_outlined;
      case CanvasEngine.e6TimelineCurve:
        return Icons.timeline;
      case CanvasEngine.e7Network:
        return Icons.hub_outlined;
      case CanvasEngine.e8SimCustom:
        return Icons.casino_outlined;
    }
  }

  static String label(CanvasEngine e) {
    switch (e) {
      case CanvasEngine.e1Quadrant:
        return '2×2 Matrix';
      case CanvasEngine.e2Force:
        return 'Force Balance';
      case CanvasEngine.e3SlidersSvg:
        return 'Live Chart';
      case CanvasEngine.e4Diagnostic:
        return 'Diagnostic';
      case CanvasEngine.e5Combinator:
        return 'Idea Studio';
      case CanvasEngine.e6TimelineCurve:
        return 'Timeline';
      case CanvasEngine.e7Network:
        return 'Network';
      case CanvasEngine.e8SimCustom:
        return 'Simulator';
    }
  }
}

/// Small rounded meta pill (engine, minutes, section).
class MetaChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;

  const MetaChip({super.key, this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface.withOpacity(0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? cs.onSurface).withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c)),
        ],
      ),
    );
  }
}

/// Four-step SuperMemo progress dots (Day 1 / 10 / 30 / 60).
class ReviewStageDots extends StatelessWidget {
  final int stage;
  final Color color;

  const ReviewStageDots({super.key, required this.stage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final filled = i < stage;
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color.withOpacity(filled ? 1 : 0.45), width: 1.2),
          ),
        );
      }),
    );
  }
}
