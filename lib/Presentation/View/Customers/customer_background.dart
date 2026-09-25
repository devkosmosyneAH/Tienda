import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class CustomerBackground extends StatelessWidget {
  const CustomerBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _CustomerBackgroundPainter()),
    );
  }
}

class _CustomerBackgroundPainter extends CustomPainter {
  const _CustomerBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final diagonalPaint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: .045)
      ..style = PaintingStyle.fill;
    final accentPaint = Paint()
      ..color = AppColors.accentColor.withValues(alpha: .08)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = AppColors.primaryLogo.withValues(alpha: .07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final patternPaint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: .055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final upperShape = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * .28)
      ..lineTo(size.width * .72, 0)
      ..close();
    canvas.drawPath(upperShape, diagonalPaint);

    final lowerShape = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * .72)
      ..lineTo(size.width * .28, size.height)
      ..close();
    canvas.drawPath(lowerShape, accentPaint);

    final stripeWidth = size.width * .34;
    for (var index = 0; index < 3; index++) {
      final offset = index * 18.0;
      final stripe = Path()
        ..moveTo(size.width - stripeWidth + offset, 0)
        ..lineTo(size.width + offset, 0)
        ..lineTo(size.width - size.height * .18 + offset, size.height * .18)
        ..lineTo(size.width - stripeWidth + offset, size.height * .18)
        ..close();
      canvas.drawPath(stripe, diagonalPaint);
    }

    final shapeWidth = size.width < 520 ? size.width * .34 : 220.0;
    final shapeHeight = size.height < 700 ? 150.0 : 190.0;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - shapeWidth - 28,
        size.height * .22,
        shapeWidth,
        shapeHeight,
      ),
      const Radius.circular(22),
    );
    canvas.drawRRect(cardRect, patternPaint);

    final cardLeft = cardRect.left + 20;
    final cardRight = cardRect.right - 20;
    for (var index = 0; index < 4; index++) {
      final lineY = cardRect.top + 38 + (index * 23);
      canvas.drawLine(
        Offset(cardLeft, lineY),
        Offset(cardRight - (index.isEven ? 16 : 42), lineY),
        patternPaint,
      );
    }

    final plusPaint = Paint()
      ..color = AppColors.accentColor.withValues(alpha: .16)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final point in [
      Offset(size.width * .12, size.height * .18),
      Offset(size.width * .86, size.height * .78),
    ]) {
      canvas.drawLine(
        Offset(point.dx - 7, point.dy),
        Offset(point.dx + 7, point.dy),
        plusPaint,
      );
      canvas.drawLine(
        Offset(point.dx, point.dy - 7),
        Offset(point.dx, point.dy + 7),
        plusPaint,
      );
    }

    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -size.width * .08,
        size.height * .08,
        size.width * 1.16,
        size.height * .84,
      ),
      const Radius.circular(34),
    );
    canvas.drawRRect(frame, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
