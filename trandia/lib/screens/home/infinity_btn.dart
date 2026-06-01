part of 'home_screen.dart';

// ═════════════════════════════════════════════════════
//  INFINITY BUTTON + ORB + PLUS PAINTER
// ═════════════════════════════════════════════════════

class _InfinityBtn extends StatefulWidget {
  final bool isDark, isOpen;
  final VoidCallback onTap, onLongPress, onDoubleTap;
  const _InfinityBtn({
    required this.isDark, required this.isOpen,
    required this.onTap, required this.onLongPress, required this.onDoubleTap,
  });
  @override
  State<_InfinityBtn> createState() => _InfinityBtnState();
}

class _InfinityBtnState extends State<_InfinityBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final Color glass  = (widget.isDark ? Colors.white : Colors.black).op(0.09);
    final Color border = (widget.isDark ? Colors.white : Colors.black).op(0.18);
    return AnimatedBuilder(animation: _ctrl,
      builder: (_, __) => Transform.scale(scale: _scale.value,
        child: GestureDetector(
          onTapDown:      (_) => _ctrl.forward(),
          onTapUp:        (_) => _ctrl.reverse(),
          onTapCancel:    () => _ctrl.reverse(),
          onTap:          widget.onTap,
          onLongPress:    widget.onLongPress,
          onLongPressEnd: (_) => _ctrl.reverse(),
          onDoubleTap:    widget.onDoubleTap,
          child: ClipOval(child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(width: kNavBtnSize, height: kNavBtnSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: glass,
                border: Border.all(color: border, width: 1),
                boxShadow: [BoxShadow(color: Colors.black.op(0.22), blurRadius: 12, offset: const Offset(0, 4))]),
              child: ClipOval(child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.cover, alignment: Alignment.center))))))));
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;
  const _Orb({required this.color, required this.size, this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.op(0.0)]))),
  );
}
