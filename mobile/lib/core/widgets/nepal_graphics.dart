import 'package:flutter/material.dart';

/// A band of repeating diamonds and triangles, an original design inspired by
/// the geometry of Nepali dhaka weaving.
class DhakaBand extends StatelessWidget {
  const DhakaBand({this.height = 16, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _DhakaPainter()),
      ),
    );
  }
}

class _DhakaPainter extends CustomPainter {
  static const _colors = [
    Color(0xFFB3261E),
    Color(0xFFF2B25F),
    Color(0xFF1565D8),
    Color(0xFFF7EFE0),
    Color(0xFF17497F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;
    canvas.drawRect(Offset.zero & size, paint..color = const Color(0xFF3A1A14));
    var i = 0;
    for (var x = 0.0; x < size.width + h; x += h) {
      // A diamond, with a smaller contrasting one inside it.
      paint.color = _colors[i % _colors.length];
      canvas.drawPath(_diamond(x, h, h / 2), paint);
      paint.color = _colors[(i + 2) % _colors.length];
      canvas.drawPath(_diamond(x, h, h / 4), paint);
      i++;
    }
  }

  Path _diamond(double x, double h, double r) {
    final cx = x + h / 2;
    final cy = h / 2;
    return Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
  }

  @override
  bool shouldRepaint(_DhakaPainter oldDelegate) => false;
}

/// A layered Himalayan ridgeline for the edge of a section.
class HimalayaSkyline extends StatelessWidget {
  const HimalayaSkyline({
    required this.color,
    required this.farColor,
    this.height = 120,
    super.key,
  });

  final Color color;
  final Color farColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SkylinePainter(color, farColor)),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.color, this.farColor);

  final Color color;
  final Color farColor;

  // Peaks as (x, height) fractions of the canvas.
  static const _far = [
    (0.0, 0.42),
    (0.08, 0.62),
    (0.15, 0.46),
    (0.24, 0.78),
    (0.32, 0.5),
    (0.42, 0.72),
    (0.5, 0.52),
    (0.6, 0.95),
    (0.68, 0.56),
    (0.78, 0.74),
    (0.88, 0.5),
    (0.95, 0.66),
    (1.0, 0.48),
  ];
  static const _near = [
    (0.0, 0.2),
    (0.1, 0.36),
    (0.2, 0.18),
    (0.34, 0.42),
    (0.46, 0.2),
    (0.58, 0.34),
    (0.7, 0.16),
    (0.84, 0.4),
    (1.0, 0.2),
  ];

  Path _ridge(Size size, List<(double, double)> points) {
    final path = Path()..moveTo(0, size.height);
    for (final (x, y) in points) {
      path.lineTo(x * size.width, size.height * (1 - y));
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_ridge(size, _far), Paint()..color = farColor);
    canvas.drawPath(_ridge(size, _near), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SkylinePainter old) =>
      old.color != color || old.farColor != farColor;
}
