import 'package:flutter/material.dart';

import 'content_block.dart';

/// Widget que renderiza una tabla Markdown con:
/// - Header con fondo diferenciado
/// - Filas alternadas sutiles
/// - Scroll horizontal para tablas anchas
/// - Bordes redondeados
class TableWidget extends StatelessWidget {
  const TableWidget({super.key, required this.block});

  final TableBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.headers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildTable(context),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final colCount = block.headers.length;

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        verticalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      children: [
        // ── Fila de headers ───────────────────────────────────────────────
        TableRow(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          children: block.headers.map((h) => _HeaderCell(text: h)).toList(),
        ),
        // ── Filas de datos ────────────────────────────────────────────────
        for (int r = 0; r < block.rows.length; r++)
          TableRow(
            decoration: BoxDecoration(
              color: r.isOdd
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.transparent,
            ),
            children: List.generate(colCount, (c) {
              final cell = c < block.rows[r].length ? block.rows[r][c] : '';
              return _DataCell(text: cell);
            }),
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        softWrap: false,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SelectableText(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 12.5,
          height: 1.4,
        ),
      ),
    );
  }
}
