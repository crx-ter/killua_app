import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ia_config_service.dart';

class IaOrquestadorException implements Exception {
  final String mensaje;
  final int? codigo;

  const IaOrquestadorException(this.mensaje, {this.codigo});

  @override
  String toString() => mensaje;
}

class IaOrquestadorService {
  static const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _siliconFlowUrl =
      'https://api.siliconflow.cn/v1/chat/completions';

  static Future<String> enviarMultimodal({
    required IaConfig config,
    required List<Map<String, dynamic>> mensajes,
    int maxTokens = 2048,
    double temperature = 0.2,
  }) async {
    final usaVision = _contieneImagen(mensajes);
    final candidatos = <_Candidato>[];

    for (final proveedor in config.proveedores) {
      if (!proveedor.disponible) continue;
      for (final modelo in proveedor.modelos) {
        if (usaVision && !modelo.vision) continue;
        if (!usaVision && modelo.vision) continue;
        candidatos.add(_Candidato(proveedor: proveedor, modelo: modelo));
      }
    }

    if (candidatos.isEmpty) {
      throw const IaOrquestadorException(
        'No hay una API key configurada para un modelo compatible con esta solicitud.',
      );
    }

    final errores = <String>[];
    for (final candidato in candidatos) {
      try {
        return await _enviar(
          candidato: candidato,
          mensajes: mensajes,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      } on IaOrquestadorException catch (error) {
        errores.add('${candidato.proveedor.nombre}: ${error.mensaje}');
      } catch (_) {
        errores.add(
          '${candidato.proveedor.nombre}: sin conexión o tiempo agotado',
        );
      }
    }

    throw IaOrquestadorException(
      'Ningún proveedor pudo responder. ${errores.join(' | ')}',
    );
  }

  static Future<String?> probarProveedor({
    required IaProveedorConfig proveedor,
  }) async {
    if (!proveedor.disponible) return 'API key no configurada';
    final modelo = proveedor.modelos.firstWhere(
      (modelo) => !modelo.vision,
      orElse: () => proveedor.modelos.first,
    );
    try {
      await _enviar(
        candidato: _Candidato(proveedor: proveedor, modelo: modelo),
        mensajes: const [
          {'role': 'user', 'content': 'Responde solo: ok'},
        ],
        maxTokens: 16,
        temperature: 0,
      );
      return null;
    } on IaOrquestadorException catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'Sin conexión o tiempo agotado';
    }
  }

  static Future<String> _enviar({
    required _Candidato candidato,
    required List<Map<String, dynamic>> mensajes,
    required int maxTokens,
    required double temperature,
  }) async {
    final proveedor = candidato.proveedor.proveedor;
    if (proveedor == IaProveedor.googleStudio) {
      return _enviarGoogle(
        candidato: candidato,
        mensajes: mensajes,
        maxTokens: maxTokens,
        temperature: temperature,
      );
    }
    return _enviarOpenAiCompatible(
      candidato: candidato,
      mensajes: mensajes,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  static Future<String> _enviarOpenAiCompatible({
    required _Candidato candidato,
    required List<Map<String, dynamic>> mensajes,
    required int maxTokens,
    required double temperature,
  }) async {
    final url = candidato.proveedor.proveedor == IaProveedor.openRouter
        ? _openRouterUrl
        : _siliconFlowUrl;
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${candidato.proveedor.apiKey}',
          },
          body: jsonEncode({
            'model': candidato.modelo.id,
            'messages': mensajes,
            'max_tokens': maxTokens,
            'temperature': temperature,
          }),
        )
        .timeout(const Duration(seconds: 90));
    return _leerRespuesta(response, candidato.proveedor.nombre);
  }

  static Future<String> _enviarGoogle({
    required _Candidato candidato,
    required List<Map<String, dynamic>> mensajes,
    required int maxTokens,
    required double temperature,
  }) async {
    final system = mensajes.where((mensaje) => mensaje['role'] == 'system');
    final contents = mensajes
        .where((mensaje) => mensaje['role'] != 'system')
        .map(_aContenidoGoogle)
        .toList();
    final query = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${candidato.modelo.id}:generateContent',
      {'key': candidato.proveedor.apiKey},
    );
    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };
    if (system.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': system.first['content']?.toString() ?? ''},
        ],
      };
    }
    final response = await http
        .post(
          query,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IaOrquestadorException(
        '${candidato.proveedor.nombre}: ${_mensajeError(response)}',
        codigo: response.statusCode,
      );
    }
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final parts = data['candidates'][0]['content']['parts'] as List;
      final text = parts
          .map((part) => part['text']?.toString() ?? '')
          .join()
          .trim();
      if (text.isEmpty) throw const FormatException();
      return text;
    } catch (_) {
      throw const IaOrquestadorException(
        'Google AI Studio devolvió una respuesta vacía o inválida.',
      );
    }
  }

  static Map<String, dynamic> _aContenidoGoogle(Map<String, dynamic> mensaje) {
    final role = mensaje['role'] == 'assistant' ? 'model' : 'user';
    final rawParts = mensaje['content'];
    final parts = rawParts is List
        ? rawParts.map(_aParteGoogle).toList()
        : [
            <String, dynamic>{'text': rawParts?.toString() ?? ''},
          ];
    return {'role': role, 'parts': parts};
  }

  static Map<String, dynamic> _aParteGoogle(dynamic parte) {
    final mapa = Map<String, dynamic>.from(parte as Map);
    if (mapa['type'] == 'text') return {'text': mapa['text'] ?? ''};
    final dataUrl = mapa['image_url']?['url']?.toString() ?? '';
    final separador = dataUrl.indexOf(';base64,');
    if (separador == -1) return {'text': '[Imagen no compatible]'};
    return {
      'inlineData': {
        'mimeType': dataUrl.substring(5, separador),
        'data': dataUrl.substring(separador + 8),
      },
    };
  }

  static bool _contieneImagen(List<Map<String, dynamic>> mensajes) {
    return mensajes.any(
      (mensaje) =>
          mensaje['content'] is List &&
          (mensaje['content'] as List).any(
            (parte) => parte is Map && parte['type'] == 'image_url',
          ),
    );
  }

  static String _leerRespuesta(http.Response response, String proveedor) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IaOrquestadorException(
        '$proveedor: ${_mensajeError(response)}',
        codigo: response.statusCode,
      );
    }
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text = data['choices'][0]['message']['content'] as String?;
      if (text == null || text.trim().isEmpty) throw const FormatException();
      return text.trim();
    } catch (_) {
      throw IaOrquestadorException(
        '$proveedor devolvió una respuesta vacía o inválida.',
      );
    }
  }

  static String _mensajeError(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final error = data['error'];
      if (error is Map) {
        return error['message']?.toString() ?? 'error desconocido';
      }
      return error?.toString() ?? 'respuesta inesperada';
    } catch (_) {
      return 'respuesta inesperada';
    }
  }
}

class _Candidato {
  final IaProveedorConfig proveedor;
  final IaModelo modelo;

  const _Candidato({required this.proveedor, required this.modelo});
}
