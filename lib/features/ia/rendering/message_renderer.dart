import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

import 'code_block_widget.dart';
import 'content_block.dart';
import 'markdown_parser.dart';
import 'quote_widget.dart';
import 'table_widget.dart';

/// Motor principal de renderizado de mensajes de IA.
///
/// Recibe un String de markdown, lo parsea en ContentBlocks y
/// construye el widget correspondiente para cada tipo de bloque.
///
/// Arquitectura:
///   MessageRenderer
///     └── MarkdownParser.parse(markdown) → `List<ContentBlock>`
///           ├── TextBlock    → MarkdownBody (flutter_markdown_plus)
///           ├── CodeBlock    → CodeBlockWidget
///           ├── TableBlock   → TableWidget
///           ├── QuoteBlock   → QuoteWidget
///           ├── DividerBlock → Divider
///           ├── MathBlock    → Math.tex (flutter_math_fork)
///           └── ImageBlock   → Image.network (futuro)
class MessageRenderer extends StatelessWidget {
  const MessageRenderer({
    super.key,
    required this.markdown,
    this.isError = false,
  });

  /// Texto en formato Markdown que se va a renderizar.
  final String markdown;

  /// Si es true, se usa un color de error para el texto.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) return const SizedBox.shrink();

    final blocks = MarkdownParser.parse(markdown);

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < blocks.length; i++)
          _buildBlock(blocks[i], i, blocks.length),
      ],
    );
  }

  Widget _buildBlock(ContentBlock block, int index, int total) {
    final isLast = index == total - 1;

    return switch (block) {
      // ── Texto / Markdown inline ───────────────────────────────────────────
      final TextBlock b => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
        child: _MarkdownText(markdown: b.markdown, isError: isError),
      ),

      // ── Bloque de codigo ─────────────────────────────────────────────────
      final CodeBlock b => CodeBlockWidget(block: b),

      // ── Tabla ─────────────────────────────────────────────────────────────
      final TableBlock b => TableWidget(block: b),

      // ── Cita ─────────────────────────────────────────────────────────────
      final QuoteBlock b => QuoteWidget(block: b),

      // ── Separador ────────────────────────────────────────────────────────
      DividerBlock() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
      ),

      // ── Matematica LaTeX ──────────────────────────────────────────────────
      final MathBlock b => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            b.latex,
            textStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
            ),
            onErrorFallback: (_) => Text(
              b.latex,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),

      // ── Imagen (futuro) ───────────────────────────────────────────────────
      final ImageBlock b => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image(
            image: _imageProvider(b.url),
            errorBuilder: (ctx, err, _) => Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Center(
                child: Text(
                  b.alt ?? 'Imagen no disponible',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      final VideoBlock b => _MarkdownVideo(url: b.url, title: b.title),
    };
  }
}

ImageProvider _imageProvider(String source) {
  final uri = Uri.tryParse(source);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(source);
  }
  return FileImage(File(source));
}

class _MarkdownVideo extends StatefulWidget {
  const _MarkdownVideo({required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<_MarkdownVideo> createState() => _MarkdownVideoState();
}

class _MarkdownVideoState extends State<_MarkdownVideo> {
  late final VideoPlayerController _video;
  ChewieController? _chewie;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    _video = uri != null && uri.hasScheme
        ? VideoPlayerController.networkUrl(uri)
        : VideoPlayerController.file(File(widget.url));
    _video
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _chewie = ChewieController(videoPlayerController: _video);
          });
        })
        .catchError((error) {
          if (mounted) setState(() => _error = error);
        });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(widget.title ?? 'Video no disponible');
    }
    final chewie = _chewie;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: chewie == null
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : AspectRatio(
              aspectRatio: _video.value.aspectRatio,
              child: Chewie(controller: chewie),
            ),
    );
  }
}

/// Widget que renderiza texto markdown inline usando flutter_markdown_plus.
/// Maneja: negrita, cursiva, codigo inline, titulos, listas y enlaces.
class _MarkdownText extends StatelessWidget {
  const _MarkdownText({required this.markdown, required this.isError});

  final String markdown;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final baseColor = isError
        ? Colors.red.shade100
        : Colors.white.withValues(alpha: 0.92);
    final dimColor = isError
        ? Colors.red.shade200
        : Colors.white.withValues(alpha: 0.65);

    return MarkdownBody(
      data: markdown,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        // ── Parrafo ────────────────────────────────────────────────────────
        p: TextStyle(color: baseColor, fontSize: 14.5, height: 1.55),
        pPadding: const EdgeInsets.only(bottom: 4),

        // ── Titulos ────────────────────────────────────────────────────────
        h1: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        h1Padding: const EdgeInsets.only(top: 4, bottom: 6),
        h2: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        h2Padding: const EdgeInsets.only(top: 4, bottom: 5),
        h3: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h3Padding: const EdgeInsets.only(top: 2, bottom: 4),
        h4: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        h5: TextStyle(
          color: Colors.white.withValues(alpha: 0.80),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        h6: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),

        // ── Negrita / Cursiva ──────────────────────────────────────────────
        strong: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        em: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontStyle: FontStyle.italic,
        ),

        // ── Codigo inline ──────────────────────────────────────────────────
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: const Color(0xFF79C0FF),
          backgroundColor: const Color(0xFF1A1F2B),
          height: 1.4,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),

        // ── Listas ─────────────────────────────────────────────────────────
        listBullet: TextStyle(color: dimColor, fontSize: 14.5),
        listBulletPadding: const EdgeInsets.only(right: 8),
        listIndent: 20,

        // ── Separador ──────────────────────────────────────────────────────
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),

        // ── Cita ───────────────────────────────────────────────────────────
        blockquote: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.white.withValues(alpha: 0.40),
              width: 3,
            ),
          ),
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),

        // ── Tabla ──────────────────────────────────────────────────────────
        tableBorder: TableBorder.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        tableHead: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tableBody: TextStyle(
          color: Colors.white.withValues(alpha: 0.80),
          fontSize: 13,
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),

        // ── Enlace ─────────────────────────────────────────────────────────
        a: const TextStyle(
          color: Color(0xFF79C0FF),
          decoration: TextDecoration.underline,
          decorationColor: Color(0x5579C0FF),
        ),
      ),
      onTapLink: (text, href, title) async {
        if (href == null) return;
        // Copiar el enlace al portapapeles como feedback
        try {
          await Clipboard.setData(ClipboardData(text: href));
        } catch (_) {}
      },
    );
  }
}
