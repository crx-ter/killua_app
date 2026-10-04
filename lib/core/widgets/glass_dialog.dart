import 'package:flutter/material.dart';

import 'glass_card.dart';

Future<T?> mostrarGlassDialog<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GlassCard(child: child),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
