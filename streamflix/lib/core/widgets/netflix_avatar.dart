import 'package:flutter/material.dart';

Color getColorForName(String name) {
  final List<Color> colors = [
    const Color(0xFFE50914), // Netflix Red
    const Color(0xFF0071EB), // Blue
    const Color(0xFF008000), // Green
    const Color(0xFFE5B209), // Yellow
    const Color(0xFF8B008B), // Purple
    const Color(0xFFD35400), // Orange
    const Color(0xFF27AE60), // Emerald
    const Color(0xFF2980B9), // Belize Hole
  ];
  int hash = 0;
  for (int i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return colors[hash.abs() % colors.length];
}

class NetflixAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool isActive;
  final bool useNetflixFace;
  final IconData? icon;
  final Widget? child;
  final Color? overrideColor;

  const NetflixAvatar({
    super.key,
    required this.name,
    this.size = 72,
    this.isActive = false,
    this.useNetflixFace = false,
    this.icon,
    this.child,
    this.overrideColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = overrideColor ?? getColorForName(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.08),
        border: isActive 
            ? Border.all(color: Colors.white, width: 2.0)
            : Border.all(color: Colors.transparent, width: 2.0),
      ),
      child: child ?? (useNetflixFace 
          ? CustomPaint(painter: NetflixSmilePainter())
          : (icon != null ? Icon(icon, color: Colors.white, size: size * 0.55) : null)),
    );
  }
}

class NetflixSmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Eyes - Made thinner
    final double eyeRadius = size.width * 0.05; 
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.38), eyeRadius, paint);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.38), eyeRadius, paint);

    // Smile - Made thinner
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.45, size.height * 0.58);
    path.quadraticBezierTo(
      size.width * 0.6, size.height * 0.70, // control point
      size.width * 0.8, size.height * 0.53, // end point
    );
    canvas.drawPath(path, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
