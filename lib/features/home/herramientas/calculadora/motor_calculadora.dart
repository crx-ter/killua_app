import 'dart:math' as math;

class ErrorCalculo implements Exception {
  final String mensaje;
  ErrorCalculo(this.mensaje);
  @override
  String toString() => mensaje;
}

class MotorCalculadora {
  final bool grados;
  final double ans;

  MotorCalculadora({required this.grados, this.ans = 0});

  late String _s;
  int _i = 0;

  static const _funciones = [
    'asin',
    'acos',
    'atan',
    'sin',
    'cos',
    'tan',
    'ln',
    'log',
  ];

  double evaluar(String expresion) {
    var s = expresion
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('π', 'p')
        .replaceAll('√', 'r')
        .replaceAll(' ', '');
    if (s.isEmpty) throw ErrorCalculo('Vacío');
    s = _prepararImplicita(s);
    _s = s;
    _i = 0;
    final v = _suma();
    if (_i < _s.length) throw ErrorCalculo('Sintaxis');
    if (v.isNaN) throw ErrorCalculo('Indefinido');
    if (v.isInfinite) throw ErrorCalculo('Infinito');
    return v;
  }

  String _prepararImplicita(String s) {
    final tokens = <String>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (_esDigito(c) || c == '.') {
        final ini = i;
        while (i < s.length && (_esDigito(s[i]) || s[i] == '.')) {
          i++;
        }
        if (i < s.length && s[i] == 'E') {
          var j = i + 1;
          if (j < s.length && (s[j] == '+' || s[j] == '-')) j++;
          final dIni = j;
          while (j < s.length && _esDigito(s[j])) {
            j++;
          }
          if (j > dIni) i = j;
        }
        tokens.add(s.substring(ini, i));
        continue;
      }
      if (s.startsWith('Ans', i)) {
        tokens.add('Ans');
        i += 3;
        continue;
      }
      var esFuncion = false;
      for (final f in _funciones) {
        if (s.startsWith(f, i)) {
          tokens.add(f);
          i += f.length;
          esFuncion = true;
          break;
        }
      }
      if (esFuncion) continue;
      tokens.add(c);
      i++;
    }

    bool terminaValor(String t) =>
        _esNumeroTok(t) ||
        t == ')' ||
        t == 'p' ||
        t == 'e' ||
        t == 'Ans' ||
        t == '!' ||
        t == '%';
    bool empiezaValor(String t) =>
        _esNumeroTok(t) ||
        t == '(' ||
        t == 'p' ||
        t == 'e' ||
        t == 'Ans' ||
        t == 'r' ||
        _funciones.contains(t);

    final out = StringBuffer();
    for (var k = 0; k < tokens.length; k++) {
      final t = tokens[k];
      if (k > 0 && terminaValor(tokens[k - 1]) && empiezaValor(t)) {
        out.write('*');
      }
      out.write(t);
    }
    return out.toString();
  }

  bool _esNumeroTok(String t) {
    if (t.isEmpty) return false;
    return _esDigito(t[0]) || t[0] == '.';
  }

  bool _hay(String c) => _i < _s.length && _s[_i] == c;

  double _suma() {
    var v = _mult();
    while (_i < _s.length && (_s[_i] == '+' || _s[_i] == '-')) {
      final op = _s[_i++];
      final d = _mult();
      v = op == '+' ? v + d : v - d;
    }
    return v;
  }

  double _mult() {
    var v = _unario();
    while (_i < _s.length && (_s[_i] == '*' || _s[_i] == '/')) {
      final op = _s[_i++];
      final d = _unario();
      if (op == '/') {
        if (d == 0) throw ErrorCalculo('No se divide entre 0');
        v /= d;
      } else {
        v *= d;
      }
    }
    return v;
  }

  double _unario() {
    if (_hay('-')) {
      _i++;
      return -_unario();
    }
    if (_hay('+')) {
      _i++;
      return _unario();
    }
    return _potencia();
  }

  double _potencia() {
    final base = _postfijo();
    if (_hay('^')) {
      _i++;
      final exp = _unario();
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  double _postfijo() {
    var v = _primario();
    while (true) {
      if (_hay('!')) {
        _i++;
        v = _factorial(v);
      } else if (_hay('%')) {
        _i++;
        v /= 100;
      } else {
        break;
      }
    }
    return v;
  }

  double _primario() {
    if (_i >= _s.length) throw ErrorCalculo('Sintaxis');
    final c = _s[_i];
    if (c == '(') {
      _i++;
      final v = _suma();
      if (_hay(')')) _i++;
      return v;
    }
    if (c == 'p') {
      _i++;
      return math.pi;
    }
    if (c == 'e') {
      _i++;
      return math.e;
    }
    if (_s.startsWith('Ans', _i)) {
      _i += 3;
      return ans;
    }
    if (c == 'r') {
      _i++;
      final v = _argumentoFuncion();
      if (v < 0) throw ErrorCalculo('Raíz de número negativo');
      return math.sqrt(v);
    }
    for (final f in _funciones) {
      if (_s.startsWith(f, _i)) {
        _i += f.length;
        return _aplicarFuncion(f, _argumentoFuncion());
      }
    }
    if (_esDigito(c) || c == '.') return _numero();
    throw ErrorCalculo('Sintaxis');
  }

  double _argumentoFuncion() {
    if (_hay('(')) {
      _i++;
      final v = _suma();
      if (_hay(')')) _i++;
      return v;
    }
    return _potencia();
  }

  double _aplicarFuncion(String nombre, double x) {
    double aRad(double v) => grados ? v * math.pi / 180 : v;
    double deRad(double v) => grados ? v * 180 / math.pi : v;
    switch (nombre) {
      case 'sin':
        return _limpiar(math.sin(aRad(x)));
      case 'cos':
        return _limpiar(math.cos(aRad(x)));
      case 'tan':
        if (_limpiar(math.cos(aRad(x))) == 0) {
          throw ErrorCalculo('tan indefinida');
        }
        return _limpiar(math.tan(aRad(x)));
      case 'asin':
        if (x < -1 || x > 1) throw ErrorCalculo('Fuera de dominio');
        return deRad(math.asin(x));
      case 'acos':
        if (x < -1 || x > 1) throw ErrorCalculo('Fuera de dominio');
        return deRad(math.acos(x));
      case 'atan':
        return deRad(math.atan(x));
      case 'ln':
        if (x <= 0) throw ErrorCalculo('Fuera de dominio');
        return math.log(x);
      case 'log':
        if (x <= 0) throw ErrorCalculo('Fuera de dominio');
        return math.log(x) / math.ln10;
      default:
        throw ErrorCalculo('Función desconocida');
    }
  }

  double _limpiar(double v) => v.abs() < 1e-12 ? 0 : v;

  double _numero() {
    final ini = _i;
    var punto = false;
    while (_i < _s.length && (_esDigito(_s[_i]) || _s[_i] == '.')) {
      if (_s[_i] == '.') {
        if (punto) throw ErrorCalculo('Sintaxis');
        punto = true;
      }
      _i++;
    }
    if (_i < _s.length && _s[_i] == 'E') {
      final guardar = _i;
      _i++;
      if (_i < _s.length && (_s[_i] == '+' || _s[_i] == '-')) _i++;
      final dIni = _i;
      while (_i < _s.length && _esDigito(_s[_i])) {
        _i++;
      }
      if (dIni == _i) _i = guardar;
    }
    final v = double.tryParse(_s.substring(ini, _i));
    if (v == null) throw ErrorCalculo('Sintaxis');
    return v;
  }

  double _factorial(double v) {
    if (v < 0 || v != v.roundToDouble()) {
      throw ErrorCalculo('Factorial solo de enteros ≥ 0');
    }
    if (v > 170) throw ErrorCalculo('Número muy grande');
    var r = 1.0;
    for (var k = 2; k <= v; k++) {
      r *= k;
    }
    return r;
  }

  bool _esDigito(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}

String formatearResultado(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  var s = v.toStringAsPrecision(12);
  if (s.contains('e')) {
    final partes = s.split('e');
    var mant = partes[0];
    if (mant.contains('.')) {
      mant = mant.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return '${mant}E${partes[1].replaceAll('+', '')}';
  }
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
