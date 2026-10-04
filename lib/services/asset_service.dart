import 'package:flutter/services.dart';

class AssetService {
  /// Retorna una lista con las rutas de todas las imágenes de fondo disponibles.
  /// Ej: ['assets/imagenes_app/fondo_1.png', 'assets/imagenes_app/fondo_2.png', ...]
  static Future<List<String>> obtenerFondosDisponibles() async {
    try {
      final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> assets = assetManifest.listAssets();
      
      final fondos = assets.where((String key) {
        return key.startsWith('assets/imagenes_app/fondo_') && key.endsWith('.png');
      }).toList();
      
      // Ordenar alfanuméricamente
      fondos.sort((a, b) {
        final reg = RegExp(r'fondo_(\d+)\.png');
        final matchA = reg.firstMatch(a);
        final matchB = reg.firstMatch(b);
        if (matchA != null && matchB != null) {
          final numA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
          final numB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
          return numA.compareTo(numB);
        }
        return a.compareTo(b);
      });
      
      return fondos;
    } catch (e) {
      // Fallback
      return [
        'assets/imagenes_app/fondo_1.png',
        'assets/imagenes_app/fondo_2.png',
      ];
    }
  }
}
