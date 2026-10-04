import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Dibuja una fórmula LaTeX. Si falla, muestra el texto tal cual.
class Formula extends StatelessWidget {
  final String tex;
  final double tamano;
  final Color? color;

  const Formula(this.tex, {super.key, this.tamano = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: tamano,
      color: color ?? Colors.white.withValues(alpha: 0.9),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        textStyle: estilo,
        onErrorFallback: (_) => Text(tex, style: estilo),
      ),
    );
  }
}
