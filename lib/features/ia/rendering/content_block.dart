/// Tipos de bloque de contenido que el parser puede producir.
sealed class ContentBlock {
  const ContentBlock();
}

/// Bloque de texto plano/markdown (parrafos, titulos, listas, negrita, etc.).
class TextBlock extends ContentBlock {
  final String markdown;
  const TextBlock(this.markdown);
}

/// Bloque de codigo con syntax highlighting.
class CodeBlock extends ContentBlock {
  final String code;
  final String language;

  const CodeBlock({required this.code, required this.language});

  String get languageNormalized {
    final l = language.toLowerCase().trim();
    return switch (l) {
      'js' => 'javascript',
      'ts' => 'typescript',
      'py' => 'python',
      'rb' => 'ruby',
      'sh' || 'bash' || 'zsh' => 'bash',
      'yml' => 'yaml',
      'md' => 'markdown',
      'kt' => 'kotlin',
      'cs' => 'cs',
      '' => 'plaintext',
      _ => l,
    };
  }

  String get languageLabel {
    if (language.isEmpty) return '';
    return switch (language.toLowerCase().trim()) {
      'js' => 'JavaScript',
      'ts' => 'TypeScript',
      'py' || 'python' => 'Python',
      'rb' || 'ruby' => 'Ruby',
      'sh' || 'bash' => 'Bash',
      'zsh' => 'Zsh',
      'yml' || 'yaml' => 'YAML',
      'md' || 'markdown' => 'Markdown',
      'kt' || 'kotlin' => 'Kotlin',
      'java' => 'Java',
      'dart' => 'Dart',
      'swift' => 'Swift',
      'go' => 'Go',
      'rust' => 'Rust',
      'cpp' || 'c++' => 'C++',
      'c' => 'C',
      'cs' || 'csharp' => 'C#',
      'php' => 'PHP',
      'sql' => 'SQL',
      'html' => 'HTML',
      'css' => 'CSS',
      'json' => 'JSON',
      'xml' => 'XML',
      'r' => 'R',
      'scala' => 'Scala',
      'lua' => 'Lua',
      _ => language,
    };
  }
}

/// Bloque de tabla Markdown.
class TableBlock extends ContentBlock {
  final List<String> headers;
  final List<List<String>> rows;
  const TableBlock({required this.headers, required this.rows});
}

/// Bloque de cita (> texto).
class QuoteBlock extends ContentBlock {
  final String content;
  const QuoteBlock(this.content);
}

/// Separador horizontal (--- o ***).
class DividerBlock extends ContentBlock {
  const DividerBlock();
}

/// Bloque de formula matematica LaTeX.
class MathBlock extends ContentBlock {
  final String latex;
  final bool isDisplay;
  const MathBlock({required this.latex, this.isDisplay = true});
}

/// Bloque de imagen (uso futuro).
class ImageBlock extends ContentBlock {
  final String url;
  final String? alt;
  const ImageBlock({required this.url, this.alt});
}

/// Bloque de video enlazado desde Markdown.
class VideoBlock extends ContentBlock {
  final String url;
  final String? title;

  const VideoBlock({required this.url, this.title});
}
