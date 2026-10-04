import 'content_block.dart';

/// Parser de Markdown a lista de ContentBlocks.
///
/// Procesa el texto linea a linea usando una maquina de estados.
/// Diseñado para ser tolerante con markdown incompleto durante streaming.
class MarkdownParser {
  /// Parsea [markdown] y devuelve la lista de bloques de contenido.
  static List<ContentBlock> parse(String markdown) {
    if (markdown.trim().isEmpty) return const [];

    final blocks = <ContentBlock>[];
    final lines = markdown.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // ── Bloque de codigo (``` o ~~~) ─────────────────────────────────────
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.startsWith('```') ? '```' : '~~~';
        final lang = trimmed.substring(fence.length).trim();
        final codeLines = <String>[];
        i++;
        bool closed = false;
        while (i < lines.length) {
          final codeLine = lines[i];
          final codeLineTrimmed = codeLine.trim();
          if (codeLineTrimmed.startsWith(fence)) {
            closed = true;
            i++;
            break;
          }
          codeLines.add(codeLine);
          i++;
        }
        // Si no se cerro (streaming incompleto), igual mostramos el codigo
        if (!closed) {
          // Quitar la ultima linea si esta vacia (tipico de streaming a medias)
          while (codeLines.isNotEmpty && codeLines.last.trim().isEmpty) {
            codeLines.removeLast();
          }
        }
        final code = codeLines.join('\n');
        if (code.isNotEmpty || lang.isNotEmpty) {
          _flushText(blocks, null); // no aplica aqui, lo manejamos fuera
          blocks.add(CodeBlock(code: code, language: lang));
        }
        continue;
      }

      // ── Bloque de math display $$...$$ o \[...\] ─────────────────────────
      if (trimmed == r'\[' || trimmed == r'$$') {
        final endMarker = trimmed == r'\[' ? r'\]' : r'$$';
        final mathLines = <String>[];
        i++;
        while (i < lines.length) {
          final mathLine = lines[i].trim();
          if (mathLine == endMarker) {
            i++;
            break;
          }
          mathLines.add(lines[i]);
          i++;
        }
        final latex = mathLines.join('\n');
        if (latex.isNotEmpty) {
          blocks.add(MathBlock(latex: latex, isDisplay: true));
        }
        continue;
      }

      // ── Tabla Markdown | col | col | ─────────────────────────────────────
      if (trimmed.startsWith('|') &&
          trimmed.endsWith('|') &&
          trimmed.length > 2) {
        final tableLines = <String>[];
        while (i < lines.length) {
          final tl = lines[i].trim();
          if (tl.startsWith('|') && tl.endsWith('|')) {
            tableLines.add(lines[i]);
            i++;
          } else {
            break;
          }
        }
        final tableBlock = _parseTable(tableLines);
        if (tableBlock != null) {
          blocks.add(tableBlock);
        }
        continue;
      }

      // ── Separador horizontal --- o *** o ___ ─────────────────────────────
      if (_isSeparator(trimmed)) {
        blocks.add(const DividerBlock());
        i++;
        continue;
      }

      // ── Cita > ───────────────────────────────────────────────────────────
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        while (i < lines.length) {
          final ql = lines[i].trim();
          if (ql.startsWith('>')) {
            quoteLines.add(ql.substring(1).trim());
            i++;
          } else if (ql.isEmpty && quoteLines.isNotEmpty) {
            i++;
            break;
          } else {
            break;
          }
        }
        final content = quoteLines.join('\n');
        if (content.isNotEmpty) {
          blocks.add(QuoteBlock(content));
        }
        continue;
      }

      // ── Imagen Markdown ![alt](url) ───────────────────────────────────────
      final imageMatch = RegExp(r'^!\[([^\]]*)\]\((\S+?)(?:\s+"[^"]*")?\)$')
          .firstMatch(trimmed);
      if (imageMatch != null) {
        final alt = imageMatch.group(1);
        final url = imageMatch.group(2) ?? '';
        if (_isVideoUrl(url)) {
          blocks.add(VideoBlock(url: url, title: alt));
        } else {
          blocks.add(ImageBlock(url: url, alt: alt));
        }
        i++;
        continue;
      }

      final videoLinkMatch = RegExp(r'^\[([^\]]+)\]\((\S+)\)$')
          .firstMatch(trimmed);
      if (videoLinkMatch != null && _isVideoUrl(videoLinkMatch.group(2)!)) {
        blocks.add(
          VideoBlock(
            url: videoLinkMatch.group(2)!,
            title: videoLinkMatch.group(1),
          ),
        );
        i++;
        continue;
      }

      // ── Texto / Markdown inline ───────────────────────────────────────────
      // Acumula lineas de texto hasta encontrar otro tipo de bloque o linea vacia
      final textLines = <String>[];
      while (i < lines.length) {
        final tl = lines[i];
        final tlTrimmed = tl.trim();

        // Para en bloques de codigo, tablas, separadores, citas, imagenes
        if (tlTrimmed.startsWith('```') || tlTrimmed.startsWith('~~~')) {
          break;
        }
        if (tlTrimmed == r'\[' || tlTrimmed == r'$$') break;
        if (tlTrimmed.startsWith('|') &&
            tlTrimmed.endsWith('|') &&
            tlTrimmed.length > 2) {
          break;
        }
        if (_isSeparator(tlTrimmed) && textLines.isNotEmpty) break;
        if (tlTrimmed.startsWith('>')) break;
        final imgMatch = RegExp(r'^!\[([^\]]*)\]\((\S+?)(?:\s+"[^"]*")?\)$')
            .firstMatch(tlTrimmed);
        if (imgMatch != null) break;

        final linkMatch = RegExp(r'^\[([^\]]+)\]\((\S+)\)$')
            .firstMatch(tlTrimmed);
        if (linkMatch != null && _isVideoUrl(linkMatch.group(2)!)) {
          break;
        }

        textLines.add(tl);
        i++;

        // Si la linea esta vacia, es el fin de un parrafo — cortamos el bloque
        if (tlTrimmed.isEmpty && textLines.length > 1) {
          break;
        }
      }

      final textContent = textLines.join('\n').trim();
      if (textContent.isNotEmpty) {
        blocks.add(TextBlock(textContent));
      } else if (textLines.every((l) => l.trim().isEmpty) &&
          textLines.isNotEmpty) {
        // lineas en blanco: no generamos bloque, solo avanzamos
      }
    }

    // Combinar TextBlocks consecutivos separados solo por espacios si son muy cortos
    return _mergeAdjacentTextBlocks(blocks);
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static void _flushText(List<ContentBlock> blocks, StringBuffer? buf) {
    if (buf == null || buf.isEmpty) return;
    final text = buf.toString().trim();
    if (text.isNotEmpty) {
      blocks.add(TextBlock(text));
    }
    buf.clear();
  }

  static bool _isSeparator(String trimmed) {
    if (trimmed.length < 3) return false;
    return (trimmed.replaceAll('-', '').isEmpty ||
            trimmed.replaceAll('*', '').isEmpty ||
            trimmed.replaceAll('_', '').isEmpty) &&
        trimmed.length >= 3;
  }

  static bool _isVideoUrl(String url) {
    final cleanUrl = url.split('?').first.split('#').first.toLowerCase();
    return cleanUrl.endsWith('.mp4') ||
        cleanUrl.endsWith('.mov') ||
        cleanUrl.endsWith('.m4v') ||
        cleanUrl.endsWith('.webm') ||
        cleanUrl.endsWith('.mkv');
  }

  static TableBlock? _parseTable(List<String> lines) {
    if (lines.isEmpty) return null;

    List<String> splitRow(String line) {
      final parts = line.split('|');
      // Quitar primer y ultimo elemento vacios (por los | externos)
      if (parts.isNotEmpty && parts.first.trim().isEmpty) parts.removeAt(0);
      if (parts.isNotEmpty && parts.last.trim().isEmpty) parts.removeLast();
      return parts.map((c) => c.trim()).toList();
    }

    bool isSeparatorRow(String line) {
      final cells = splitRow(line);
      return cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c.trim()));
    }

    if (lines.length < 2) return null;
    if (!isSeparatorRow(lines[1])) return null;

    final headers = splitRow(lines[0]);
    final rows = <List<String>>[];

    for (int i = 2; i < lines.length; i++) {
      if (isSeparatorRow(lines[i])) continue;
      rows.add(splitRow(lines[i]));
    }

    return TableBlock(headers: headers, rows: rows);
  }

  /// Combina TextBlocks adyacentes que son solo separaciones de parrafo
  /// para reducir el numero de widgets y mejorar el rendimiento.
  static List<ContentBlock> _mergeAdjacentTextBlocks(
    List<ContentBlock> blocks,
  ) {
    if (blocks.length <= 1) return blocks;

    final result = <ContentBlock>[];
    final pendingText = StringBuffer();

    for (final block in blocks) {
      if (block is TextBlock) {
        if (pendingText.isNotEmpty) {
          pendingText.write('\n\n');
        }
        pendingText.write(block.markdown);
      } else {
        if (pendingText.isNotEmpty) {
          result.add(TextBlock(pendingText.toString()));
          pendingText.clear();
        }
        result.add(block);
      }
    }

    if (pendingText.isNotEmpty) {
      result.add(TextBlock(pendingText.toString()));
    }

    return result;
  }
}
