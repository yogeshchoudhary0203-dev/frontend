import 'package:flutter/material.dart';

extension ColorOpacity on Color {
  Color op(double opacity) => withValues(alpha: opacity);
}

class HomeOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;
  const HomeOrb({super.key, required this.color, required this.size, this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.op(0.0)]))),
  );
}

const double kNavBtnSize = 64.0;
const double kNavWidth   = kNavBtnSize;
const double kItemH      = 54.0;
const double kNavGap     = 6.0;
const double kIconSize   = 20.0;

final ValueNotifier<bool> homeFeedActive = ValueNotifier(true);
