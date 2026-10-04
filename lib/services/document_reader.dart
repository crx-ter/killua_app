import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extrae texto legible de varios formatos de documento.
/// Soporta: PDF (texto estructurado), DOCX, XLSX, PPTX (archivos ZIP con XML).
class DocumentReader {
  /// Intenta extraer texto del contenido del documento (bytes).
  /// [mime] es el tipo MIME del archivo para determinar el formato.
  static Future<String?> extractText(
    List<int> bytes, {
    required String mime,
  }) async {
    final mimeLower = mime.toLowerCase();

    // 1. Intentar extraer texto de PDF
    if (mimeLower == 'application/pdf' || mimeLower == 'application/x-pdf') {
      final pdfText = _extractPdfText(bytes);
      if (pdfText != null && pdfText.isNotEmpty) return pdfText;
    }

    // 2. Documentos Office (DOCX, XLSX, PPTX) - son archivos ZIP con XML
    final officeText = _extractOfficeText(bytes, mimeLower);
    if (officeText != null && officeText.isNotEmpty) return officeText;

    // 3. Otros formatos de imagen/texto plano
    if (mimeLower.startsWith('image/')) {
      return '[Archivo de imagen - ver preview en el visor]';
    }

    return null;
  }

  /// Extrae texto intentando leer la estructura interna de un PDF.
  static String? _extractPdfText(List<int> bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final texto = PdfTextExtractor(document).extractText();
      document.dispose();
      final limpio = texto.trim();
      if (limpio.isEmpty) return null;
      return limpio.length > 12000
          ? '${limpio.substring(0, 12000)}...[texto truncado]'
          : limpio;
    } catch (e) {
      return null;
    }
  }

  /// Extrae texto de documentos Office (DOCX, XLSX, PPTX).
  static String? _extractOfficeText(List<int> bytes, String mimeLower) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final texts = <String>[];

      for (final file in archive) {
        if (!file.isFile) continue;
        final nombre = file.name.toLowerCase();

        bool esArchivoRelevante = false;
        String? categoria;

        if (mimeLower ==
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
            mimeLower == 'application/msword') {
          esArchivoRelevante =
              nombre.startsWith('word/') && nombre.endsWith('.xml');
          categoria = 'DOCX';
        } else if (mimeLower ==
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
            mimeLower == 'application/vnd.ms-excel') {
          esArchivoRelevante =
              nombre.startsWith('xl/') && nombre.endsWith('.xml');
          categoria = 'XLSX';
        } else if (mimeLower ==
                'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
            mimeLower == 'application/vnd.ms-powerpoint') {
          esArchivoRelevante =
              nombre.startsWith('ppt/') && nombre.endsWith('.xml');
          categoria = 'PPTX';
        }

        if (esArchivoRelevante) {
          try {
            final texto = String.fromCharCodes(file.content)
                .replaceAll(RegExp(r'[\x00-\x1f]'), '');
            if (texto.isNotEmpty) {
              texts.add('[$categoria]: $texto');
            }
          } catch (_) {
            // Ignorar errores
          }
        }
      }

      if (texts.isEmpty) return null;
      final todo = texts.join('\n').trim();
      return todo.length > 5000
          ? '${todo.substring(0, 5000)}...[texto truncado]'
          : todo;
    } catch (e) {
      return null;
    }
  }
}
