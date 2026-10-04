import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _claveHash = 'killua_password';

  static Future<bool> tienePassword() async {
    try {
      final valor = await _storage.read(key: _claveHash);
      return valor != null && valor.isNotEmpty;
    } catch (e) {
      // En caso de que el Keystore de Android se corrompa por una reinstalación
      return false;
    }
  }

  /// Guarda o cambia la contraseña.
  static Future<void> guardarPassword(String password) async {
    try {
      await _storage.write(key: _claveHash, value: password);
    } catch (e) {
      // Intentar limpiar almacenamiento si falla por corrupción
      await _storage.deleteAll();
      await _storage.write(key: _claveHash, value: password);
    }
  }

  /// Verifica si la contraseña ingresada es correcta.
  static Future<bool> verificar(String password) async {
    try {
      final guardada = await _storage.read(key: _claveHash);
      return guardada == password;
    } catch (e) {
      return false;
    }
  }

  /// Quita la contraseña (la app entrará directo al home).
  static Future<void> eliminarPassword() async {
    await _storage.delete(key: _claveHash);
  }
}
