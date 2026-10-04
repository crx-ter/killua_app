import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const BouncingWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
  });

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.onTap != null && _isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (widget.onTap != null && _isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.onTap != null) {
            HapticFeedback.lightImpact();
            widget.onTap!();
          }
        },
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: _isPressed ? 0.25 : 0.0),
            BlendMode.srcATop,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
