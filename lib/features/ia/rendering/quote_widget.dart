import 'package:flutter/material.dart';

import 'content_block.dart';

/// Widget que renderiza una cita markdown (> texto)
/// con barra lateral, fondo tenue y estilo diferenciado.
class QuoteWidget extends StatelessWidget {
  const QuoteWidget({super.key, required this.block});

  final QuoteBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.40),
            width: 3,
          ),
        ),
      ),
      child: SelectableText(
        block.content,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 14,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
