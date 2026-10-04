import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum IaProveedor { openRouter, googleStudio, siliconFlow }

class IaModelo {
  final String id;
  final bool vision;
  final bool codigo;

  const IaModelo(this.id, {this.vision = false, this.codigo = false});
}

class IaProveedorConfig {
  final IaProveedor proveedor;
  final String nombre;
  final String apiKey;
  final List<IaModelo> modelos;

  const IaProveedorConfig({
    required this.proveedor,
    required this.nombre,
    required this.apiKey,
    required this.modelos,
  });

  bool get disponible => apiKey.trim().isNotEmpty;
}

class IaConfig {
  final List<IaProveedorConfig> proveedores;

  const IaConfig({required this.proveedores});

  bool get lista => proveedores.any((proveedor) => proveedor.disponible);
}

class IaConfigService {
  static const _storage = FlutterSecureStorage();
  static const _kOpenRouterKey = 'killua_ia_openrouter_api_key';
  static const _kGoogleStudioKey = 'killua_ia_google_studio_api_key';
  static const _kSiliconFlowKey = 'killua_ia_siliconflow_api_key';

  static const openRouterModelos = [
    IaModelo(
      'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
      vision: true,
    ),
    IaModelo('qwen/qwen3.8-27b:free'),
    IaModelo('cohere/north-mini-code:free', codigo: true),
    IaModelo('poolside/laguna-s-2.1:free', codigo: true),
  ];

  static const googleStudioModelos = [
    IaModelo('poolside/laguna-s-2.1:free'),
    IaModelo('gemini-1.5-pro', vision: true),
    IaModelo('gemini-2.0-flash', vision: true),
  ];

  static const siliconFlowModelos = [
    IaModelo('Qwen/Qwen2.5-VL-72B-Instruct', vision: true),
    IaModelo('Qwen/Qwen2.5-Coder-32B-Instruct', codigo: true),
  ];

  static Future<IaConfig> leer() async {
    final keys = await Future.wait([
      _storage.read(key: _kOpenRouterKey),
      _storage.read(key: _kGoogleStudioKey),
      _storage.read(key: _kSiliconFlowKey),
    ]);
    return IaConfig(
      proveedores: [
        IaProveedorConfig(
          proveedor: IaProveedor.openRouter,
          nombre: 'OpenRouter',
          apiKey: keys[0] ?? '',
          modelos: openRouterModelos,
        ),
        IaProveedorConfig(
          proveedor: IaProveedor.googleStudio,
          nombre: 'Google AI Studio',
          apiKey: keys[1] ?? '',
          modelos: googleStudioModelos,
        ),
        IaProveedorConfig(
          proveedor: IaProveedor.siliconFlow,
          nombre: 'SiliconFlow',
          apiKey: keys[2] ?? '',
          modelos: siliconFlowModelos,
        ),
      ],
    );
  }

  static Future<void> guardar({
    required String openRouterKey,
    required String googleStudioKey,
    required String siliconFlowKey,
  }) async {
    await _guardarClave(_kOpenRouterKey, openRouterKey);
    await _guardarClave(_kGoogleStudioKey, googleStudioKey);
    await _guardarClave(_kSiliconFlowKey, siliconFlowKey);
  }

  static Future<void> _guardarClave(String storageKey, String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: storageKey);
    } else {
      await _storage.write(key: storageKey, value: value.trim());
    }
  }
}
