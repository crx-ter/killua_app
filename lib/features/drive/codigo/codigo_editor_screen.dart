import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../services/theme_config_service.dart';
import '../datos/drive_repositorio.dart';
import '../modelos/drive_elemento.dart';
import 'lenguajes_soportados.dart';

class CodigoEditorScreen extends StatefulWidget {
  const CodigoEditorScreen({
    super.key,
    required this.codigo,
    required this.repositorio,
  });

  final DriveElemento codigo;
  final DriveRepositorio repositorio;

  @override
  State<CodigoEditorScreen> createState() => _CodigoEditorScreenState();
}

class _CodigoEditorScreenState extends State<CodigoEditorScreen> {
  late CodeController _controlador;
  Timer? _debounce;
  bool _guardando = false;
  bool _mostrandoVistaPrevia = false;
  bool _ejecutando = false;
  String _salida = '';
  late final WebViewController _webController;
  late String _lenguajeActual;

  @override
  void initState() {
    super.initState();
    _lenguajeActual = widget.codigo.lenguaje ?? 'dart';

    _controlador = CodeController(
      text: widget.codigo.contenido ?? '',
      language: lenguajesSoportados[_lenguajeActual],
    );

    _controlador.addListener(_enCambioDeTexto);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  void _enCambioDeTexto() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _guardar);
  }

  Future<void> _guardar() async {
    if (!mounted) return;
    setState(() => _guardando = true);

    try {
      final actualizado = widget.codigo.copyWith(
        contenido: _controlador.text,
        lenguaje: _lenguajeActual,
        modificado: DateTime.now(),
      );
      await widget.repositorio.guardar(actualizado);
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _mostrarVistaPrevia() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mostrandoVistaPrevia = true);
    if (_lenguajeActual == 'html') {
      await _webController.loadHtmlString(_controlador.text);
      return;
    }
    await _ejecutarCodigo();
  }

  Future<void> _ejecutarCodigo() async {
    setState(() => _ejecutando = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final contenido = _controlador.text;
    final lineas = contenido.split('\n');
    final resultados = <String>[];
    final variables = <String, Object?>{};
    final patron = RegExp(
      r'''(?:print|println|puts|echo|console\.log|System\.out\.println)\s*\((.*?)\)|(?:^|\s)echo\s+(.+)$|cout\s*<<\s*(.+?)(?:;|$)''',
      caseSensitive: false,
    );
    for (final linea in lineas) {
      final codigo = linea.trim();
      if (codigo.isEmpty || codigo.startsWith('//') || codigo.startsWith('#')) {
        continue;
      }
      final asignacion = RegExp(
        r'^(?:let|const|var)?\s*([A-Za-z_]\w*)\s*=\s*(.+?);?$',
      ).firstMatch(codigo);
      if (asignacion != null && !codigo.startsWith('print')) {
        variables[asignacion.group(1)!] = _evaluarExpresion(
          asignacion.group(2)!,
          variables,
        );
        continue;
      }
      final coincidencia = patron.firstMatch(codigo);
      if (coincidencia == null) continue;
      final valor =
          coincidencia.group(1) ??
          coincidencia.group(2) ??
          coincidencia.group(3) ??
          '';
      resultados.add(
        _limpiarSalida(
          _formatearResultado(_evaluarExpresion(valor, variables)),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _salida = resultados.isEmpty
          ? 'No se detectó una salida de consola.\n\nEste lenguaje necesita un runtime local para ejecutar el programa completo.'
          : resultados.join('\n');
      _ejecutando = false;
    });
  }

  String _limpiarSalida(String valor) {
    var salida = valor.trim().replaceAll(RegExp(r';\s*$'), '');
    if ((salida.startsWith('"') && salida.endsWith('"')) ||
        (salida.startsWith("'") && salida.endsWith("'"))) {
      salida = salida.substring(1, salida.length - 1);
    }
    return salida.replaceAll(r'\n', '\n');
  }

  Object? _evaluarExpresion(String expresion, Map<String, Object?> variables) {
    try {
      return _ExpresionCodigo(expresion, variables).leer();
    } catch (_) {
      return expresion.trim();
    }
  }

  String _formatearResultado(Object? resultado) {
    if (resultado is double && resultado == resultado.truncateToDouble()) {
      return resultado.toInt().toString();
    }
    return resultado.toString();
  }

  Widget _panelSalida(ThemeConfigService themeConfig) {
    if (_lenguajeActual == 'html') {
      return WebViewWidget(controller: _webController);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: SelectableText(
        _ejecutando ? 'Ejecutando...' : _salida,
        style: TextStyle(
          color: themeConfig.currentTextColor.withValues(alpha: 0.88),
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: themeConfig.glassColor.withValues(
          alpha: themeConfig.glassOpacity,
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: themeConfig.currentTextColor),
        title: Text(
          widget.codigo.nombre,
          style: TextStyle(
            color: themeConfig.currentTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedOpacity(
                opacity: _guardando ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: themeConfig.currentTextColor.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Guardando...',
                      style: TextStyle(
                        color: themeConfig.currentTextColor.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previsualizar y ejecutar',
                  icon: Icon(
                    _mostrandoVistaPrevia
                        ? Icons.code_outlined
                        : Icons.visibility_outlined,
                    color: themeConfig.currentTextColor,
                  ),
                  onPressed: () {
                    if (_mostrandoVistaPrevia) {
                      setState(() => _mostrandoVistaPrevia = false);
                    } else {
                      _mostrarVistaPrevia();
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.code, color: themeConfig.currentTextColor),
                  color: const Color(0xFF282B34),
                  initialValue: _lenguajeActual,
                  onSelected: (String lang) {
                    setState(() {
                      _lenguajeActual = lang;
                      _controlador.language = lenguajesSoportados[lang];
                    });
                    _guardar();
                  },
                  itemBuilder: (BuildContext context) {
                    return listaNombresLenguajes.map((String lang) {
                      return PopupMenuItem<String>(
                        value: lang,
                        child: Text(
                          lang,
                          style: TextStyle(
                            color: _lenguajeActual == lang
                                ? Colors.amberAccent
                                : Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (themeConfig.isSolidBlack)
            Container(color: Colors.black)
          else if (themeConfig.isSolidWhite)
            Container(color: Colors.white)
          else
            Image.asset(themeConfig.fondoPath, fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _mostrandoVistaPrevia
                        ? _panelSalida(themeConfig)
                        : Align(
                            alignment: Alignment.topLeft,
                            child: CodeTheme(
                              data: CodeThemeData(styles: atomOneDarkTheme),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.zero,
                                child: CodeField(
                                  controller: _controlador,
                                  textStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                  gutterStyle: GutterStyle(
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                    margin: 8,
                                    showLineNumbers: true,
                                    showErrors: true,
                                    showFoldingHandles: true,
                                  ),
                                  expands: false,
                                  wrap: false,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpresionCodigo {
  _ExpresionCodigo(this.texto, this.variables);

  final String texto;
  final Map<String, Object?> variables;
  var posicion = 0;

  Object? leer() {
    final resultado = _suma();
    _espacios();
    if (posicion != texto.length) throw const FormatException();
    return resultado;
  }

  Object? _suma() {
    var izquierda = _producto();
    while (true) {
      _espacios();
      if (_aceptar('+')) {
        izquierda = _operar(izquierda, _producto(), '+');
      } else if (_aceptar('-')) {
        izquierda = _operar(izquierda, _producto(), '-');
      } else {
        return izquierda;
      }
    }
  }

  Object? _producto() {
    var izquierda = _unario();
    while (true) {
      _espacios();
      var operador = '';
      if (_aceptar('*')) operador = '*';
      if (operador.isEmpty && _aceptar('/')) operador = '/';
      if (operador.isEmpty && _aceptar('%')) operador = '%';
      if (operador.isEmpty && _siguienteIniciaFactor()) operador = '*';
      if (operador.isEmpty) return izquierda;
      izquierda = _operar(izquierda, _unario(), operador);
    }
  }

  Object? _unario() {
    _espacios();
    if (_aceptar('-')) return -_numero(_unario());
    if (_aceptar('+')) return _numero(_unario());
    return _factor();
  }

  Object? _factor() {
    _espacios();
    if (_aceptar('(')) {
      final valor = _suma();
      if (!_aceptar(')')) throw const FormatException();
      return valor;
    }
    if (posicion < texto.length &&
        (texto[posicion] == '"' || texto[posicion] == "'")) {
      final comilla = texto[posicion++];
      final inicio = posicion;
      while (posicion < texto.length && texto[posicion] != comilla) {
        posicion++;
      }
      final valor = texto.substring(inicio, posicion);
      if (posicion < texto.length) posicion++;
      return valor;
    }
    final inicio = posicion;
    while (posicion < texto.length &&
        RegExp(r'[A-Za-z0-9_.]').hasMatch(texto[posicion])) {
      posicion++;
    }
    if (inicio == posicion) throw const FormatException();
    final token = texto.substring(inicio, posicion);
    return double.tryParse(token) ?? variables[token] ?? token;
  }

  bool _siguienteIniciaFactor() {
    if (posicion >= texto.length) return false;
    final caracter = texto[posicion];
    return caracter == '(' || RegExp(r'[A-Za-z0-9_]').hasMatch(caracter);
  }

  Object _operar(Object? izquierda, Object? derecha, String operador) {
    if (operador == '+' && (izquierda is String || derecha is String)) {
      return '${izquierda ?? ''}${derecha ?? ''}';
    }
    final izquierdo = _numero(izquierda);
    final derecho = _numero(derecha);
    return switch (operador) {
      '+' => izquierdo + derecho,
      '-' => izquierdo - derecho,
      '*' => izquierdo * derecho,
      '/' => izquierdo / derecho,
      '%' => izquierdo % derecho,
      _ => throw const FormatException(),
    };
  }

  double _numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    return double.parse(valor.toString());
  }

  bool _aceptar(String caracter) {
    _espacios();
    if (posicion < texto.length && texto[posicion] == caracter) {
      posicion++;
      return true;
    }
    return false;
  }

  void _espacios() {
    while (posicion < texto.length && texto[posicion].trim().isEmpty) {
      posicion++;
    }
  }
}
