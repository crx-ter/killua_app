import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeConfigService extends ChangeNotifier {
  static const String _keyFondo = 'theme_fondo';
  static const String _keyGlassColor = 'theme_glass_color';
  static const String _keyGlassOpacity = 'theme_glass_opacity';
  static const String _keyFontSizeDelta = 'theme_font_size_delta';
  static const String _keyOverrideTextColor = 'theme_override_text_color';
  static const String _keyHighContrastLines = 'theme_high_contrast_lines';

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Valores por defecto
  String _fondoPath = 'assets/imagenes_app/fondo_1.png';
  Color _glassColor = Colors.white;
  double _glassOpacity = 0.1;
  double _fontSizeDelta = 0.0;
  Color? _overrideTextColor; // null = Auto
  bool _highContrastLines = false;

  // Getters
  bool get isInitialized => _initialized;
  String get fondoPath => _fondoPath;
  Color get glassColor => _glassColor;
  double get glassOpacity => _glassOpacity;
  double get fontSizeDelta => _fontSizeDelta;
  Color? get overrideTextColor => _overrideTextColor;
  bool get highContrastLines => _highContrastLines;

  /// Retorna si el fondo actual es sólido negro o blanco
  bool get isSolidBlack => _fondoPath == 'solid_black';
  bool get isSolidWhite => _fondoPath == 'solid_white';

  /// Auto-calcula el color de texto ideal si no hay override
  Color get currentTextColor {
    if (_overrideTextColor != null) return _overrideTextColor!;
    if (isSolidWhite) return Colors.black87;
    // Para fondos de imagen, el valor por defecto en la app ha sido texto claro.
    return Colors.white.withValues(alpha: 0.92);
  }

  /// Color para líneas y bordes
  Color get currentLineColor {
    final base = isSolidWhite ? Colors.black : Colors.white;
    return base.withValues(alpha: _highContrastLines ? 0.35 : 0.15);
  }

  /// Inicializa el servicio cargando los valores de SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    _fondoPath = _prefs.getString(_keyFondo) ?? 'assets/imagenes_app/fondo_1.png';
    
    final colorValue = _prefs.getInt(_keyGlassColor);
    if (colorValue != null) {
      _glassColor = Color(colorValue);
    }
    
    _glassOpacity = _prefs.getDouble(_keyGlassOpacity) ?? 0.1;
    _fontSizeDelta = _prefs.getDouble(_keyFontSizeDelta) ?? 0.0;
    
    final textColorValue = _prefs.getInt(_keyOverrideTextColor);
    if (textColorValue != null) {
      _overrideTextColor = textColorValue == 0 ? null : Color(textColorValue);
    }

    _highContrastLines = _prefs.getBool(_keyHighContrastLines) ?? false;
    
    _initialized = true;
    notifyListeners();
  }

  // Setters que guardan en preferencias y notifican a la UI

  void setFondoPath(String path) {
    _fondoPath = path;
    _prefs.setString(_keyFondo, path);
    notifyListeners();
  }

  void setGlassColor(Color color) {
    _glassColor = color;
    _prefs.setInt(_keyGlassColor, color.toARGB32());
    notifyListeners();
  }

  void setGlassOpacityPreview(double opacity) {
    _glassOpacity = opacity;
    notifyListeners(); // Solo actualiza UI temporalmente
  }

  void setGlassOpacity(double opacity) {
    _glassOpacity = opacity;
    _prefs.setDouble(_keyGlassOpacity, opacity);
    notifyListeners();
  }

  void setFontSizeDeltaPreview(double delta) {
    _fontSizeDelta = delta;
    notifyListeners(); // Solo actualiza UI temporalmente
  }

  void setFontSizeDelta(double delta) {
    _fontSizeDelta = delta;
    _prefs.setDouble(_keyFontSizeDelta, delta);
    notifyListeners();
  }

  void setOverrideTextColor(Color? color) {
    _overrideTextColor = color;
    _prefs.setInt(_keyOverrideTextColor, color?.toARGB32() ?? 0);
    notifyListeners();
  }

  void setHighContrastLines(bool value) {
    _highContrastLines = value;
    _prefs.setBool(_keyHighContrastLines, value);
    notifyListeners();
  }
}
