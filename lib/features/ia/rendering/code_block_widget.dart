import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import 'content_block.dart';

/// Widget que renderiza un bloque de codigo con:
/// - Syntax highlighting (flutter_highlight)
/// - Etiqueta de lenguaje
/// - Boton copiar con feedback visual
/// - Scroll horizontal para lineas largas
/// - Fuente monoespacio
class CodeBlockWidget extends StatefulWidget {
  const CodeBlockWidget({super.key, required this.block});

  final CodeBlock block;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.block.code));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.block.languageLabel.isNotEmpty;
    final lang = widget.block.languageNormalized;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0D1117),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: lenguaje + boton copiar ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Etiqueta del lenguaje
                if (hasLabel)
                  Text(
                    widget.block.languageLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  Text(
                    'Codigo',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 11,
                    ),
                  ),

                // Boton copiar
                GestureDetector(
                  onTap: _copiar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: _copiado
                          ? Colors.greenAccent.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: _copiado
                            ? Colors.greenAccent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copiado ? Icons.check : Icons.content_copy_rounded,
                          size: 12,
                          color: _copiado
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _copiado ? 'Copiado' : 'Copiar',
                          style: TextStyle(
                            fontSize: 11,
                            color: _copiado
                                ? Colors.greenAccent
                                : Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Cuerpo: codigo con highlight + scroll horizontal ────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: _buildHighlight(lang),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(String lang) {
    // Lista de lenguajes soportados por flutter_highlight
    const supported = {
      'dart', 'python', 'javascript', 'typescript', 'java', 'kotlin',
      'swift', 'go', 'rust', 'cpp', 'c', 'cs', 'php', 'ruby', 'bash',
      'sql', 'html', 'css', 'json', 'xml', 'yaml', 'markdown', 'scala',
      'lua', 'r',
    };

    final useLang = supported.contains(lang) ? lang : 'plaintext';

    try {
      return HighlightView(
        widget.block.code,
        language: useLang == 'plaintext' ? 'bash' : useLang,
        theme: _darkTheme,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.55,
          letterSpacing: 0,
        ),
      );
    } catch (_) {
      // Fallback si el lenguaje no es soportado
      return SelectableText(
        widget.block.code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.55,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      );
    }
  }
}

/// Tema oscuro personalizado para el syntax highlighting,
/// derivado de atom-one-dark con ajustes para el glassmorphism.
final Map<String, TextStyle> _darkTheme = {
  ...atomOneDarkTheme,
  'root': TextStyle(
    color: const Color(0xFFABB2BF),
    backgroundColor: Colors.transparent,
  ),
};
