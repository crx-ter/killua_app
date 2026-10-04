import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_config_service.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);
    final color = themeConfig.glassColor;
    final alphaBase = themeConfig.glassOpacity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: alphaBase + 0.08),
                color.withValues(alpha: alphaBase),
              ],
            ),
            border: Border.all(
              color: themeConfig.currentLineColor,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
