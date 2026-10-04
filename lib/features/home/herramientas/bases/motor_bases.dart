enum Base { decimal, binario, octal, hexadecimal }

extension BaseInfo on Base {
  int get radix => switch (this) {
    Base.decimal => 10,
    Base.binario => 2,
    Base.octal => 8,
    Base.hexadecimal => 16,
  };

  String get nombre => switch (this) {
    Base.decimal => 'Decimal',
    Base.binario => 'Binario',
    Base.octal => 'Octal',
    Base.hexadecimal => 'Hexadecimal',
  };

  String get corto => switch (this) {
    Base.decimal => 'DEC',
    Base.binario => 'BIN',
    Base.octal => 'OCT',
    Base.hexadecimal => 'HEX',
  };

  String get digitosValidos => switch (this) {
    Base.decimal => '0-9',
    Base.binario => '0 y 1',
    Base.octal => '0-7',
    Base.hexadecimal => '0-9 y A-F',
  };
}

/// Un bloque por sistema destino. Las líneas van en LaTeX.
class BloqueConversion {
  final Base base;
  final String resultado;
  final List<String> conversion;
  final List<String> comprobacion;

  BloqueConversion({
    required this.base,
    required this.resultado,
    required this.conversion,
    required this.comprobacion,
  });
}

class MotorBases {
  static const _hexDigitos = '0123456789ABCDEF';

  static String? validar(String entrada, Base origen) {
    final e = entrada.trim().toUpperCase();
    if (e.isEmpty) return 'Ingresa un valor';
    for (final c in e.split('')) {
      final v = _hexDigitos.indexOf(c);
      if (v == -1 || v >= origen.radix) {
        return "'$c' no es válido en ${origen.nombre} "
            '(usa ${origen.digitosValidos})';
      }
    }
    if (e.length > 15) return 'Máximo 15 dígitos';
    return null;
  }

  static int aDecimal(String entrada, Base origen) =>
      int.parse(entrada.trim().toUpperCase(), radix: origen.radix);

  static List<BloqueConversion> convertir({
    required String entrada,
    required Base origen,
    required Set<Base> destinos,
  }) {
    final e = entrada.trim().toUpperCase();
    final valor = aDecimal(e, origen);
    final bloques = <BloqueConversion>[];

    for (final destino in Base.values) {
      if (!destinos.contains(destino)) continue;
      if (destino == origen) continue;

      switch (destino) {
        case Base.decimal:
          bloques.add(_aDecimalBloque(e, origen, valor));
        case Base.binario:
          bloques.add(_aBinarioBloque(valor));
        case Base.octal:
          bloques.add(_aOctalBloque(valor));
        case Base.hexadecimal:
          bloques.add(_aHexBloque(valor));
      }
    }
    return bloques;
  }

  // ------------------------------------------------------------
  // Origen → Decimal: suma posicional
  // ------------------------------------------------------------
  static BloqueConversion _aDecimalBloque(String e, Base origen, int valor) {
    final comprobacion = <String>[];
    final equivalencias = _equivalencias(e);
    if (equivalencias != null) comprobacion.add(equivalencias);

    return BloqueConversion(
      base: Base.decimal,
      resultado: '$valor',
      conversion: _desglosePosicional(e, origen.radix, valor),
      comprobacion: [
        ...comprobacion,
        '${e.length} \\text{ dígitos en base } ${origen.radix}',
      ]..removeLast(),
    );
  }

  // ------------------------------------------------------------
  // Decimal → Binario: restas por potencias de 2
  // ------------------------------------------------------------
  static BloqueConversion _aBinarioBloque(int valor) {
    final bits = _bitsNecesarios(valor);
    final binario = _binarioAgrupado(valor, bits);

    final conv = <String>[];
    final potenciasUsadas = <int>[];
    var temp = valor;

    for (var i = bits - 1; i >= 0; i--) {
      final potencia = 1 << i;
      if (temp >= potencia) {
        final nuevo = temp - potencia;
        conv.add('$temp - $potencia = $nuevo');
        potenciasUsadas.add(potencia);
        temp = nuevo;
      }
    }
    if (conv.isEmpty) conv.add('0 = 0');

    return BloqueConversion(
      base: Base.binario,
      resultado: binario,
      conversion: conv,
      comprobacion: [
        valor == 0 ? '0 = 0' : '${potenciasUsadas.join(' + ')} = $valor',
      ],
    );
  }

  // ------------------------------------------------------------
  // Decimal → Octal: divisiones entre 8, formato de cuaderno
  //   90 ÷ 8 = 11.25  →  0.25 × 8 = 2
  // ------------------------------------------------------------
  static BloqueConversion _aOctalBloque(int valor) {
    final conv = <String>[];
    var octal = '';
    var t = valor;

    if (t == 0) {
      octal = '0';
      conv.add('0 \\div 8 = 0 \\;\\to\\; 0 \\times 8 = 0');
    } else {
      while (t > 0) {
        final cociente = t ~/ 8;
        final residuo = t % 8;
        if (residuo == 0) {
          conv.add('$t \\div 8 = $cociente \\;\\to\\; 0 \\times 8 = 0');
        } else {
          final dec = _decimalDeResiduo(residuo);
          conv.add(
            '$t \\div 8 = $cociente.$dec \\;\\to\\; '
            '0.$dec \\times 8 = $residuo',
          );
        }
        octal = '$residuo$octal';
        t = cociente;
      }
    }

    return BloqueConversion(
      base: Base.octal,
      resultado: octal,
      conversion: conv,
      comprobacion: _desglosePosicional(octal, 8, valor),
    );
  }

  // ------------------------------------------------------------
  // Decimal → Hexadecimal: nibbles + equivalencias
  // ------------------------------------------------------------
  static BloqueConversion _aHexBloque(int valor) {
    final bits = _bitsNecesarios(valor);
    final binario = _binarioAgrupado(valor, bits);

    final conv = <String>[];
    var hex = '';
    for (final nib in binario.split(' ')) {
      final val = int.parse(nib, radix: 2);
      final ch = _hexDigitos[val];
      hex += ch;
      conv.add('$nib = $val \\to \\text{$ch}');
    }

    final comprobacion = <String>[];
    final equivalencias = _equivalencias(hex);
    if (equivalencias != null) comprobacion.add(equivalencias);
    comprobacion.addAll(_desglosePosicional(hex, 16, valor));

    return BloqueConversion(
      base: Base.hexadecimal,
      resultado: hex,
      conversion: conv,
      comprobacion: comprobacion,
    );
  }

  // ------------------------------------------------------------
  // Utilidades
  // ------------------------------------------------------------

  /// dígito × base^exp = valor, una línea por dígito, y la suma final.
  static List<String> _desglosePosicional(String texto, int base, int total) {
    final lineas = <String>[];
    final valores = <int>[];
    final n = texto.length;

    for (var i = 0; i < n; i++) {
      final dig = _hexDigitos.indexOf(texto[i]);
      final exp = n - 1 - i;
      var pot = 1;
      for (var k = 0; k < exp; k++) {
        pot *= base;
      }
      final valor = dig * pot;
      valores.add(valor);
      lineas.add('$dig \\times $base^{$exp} = $valor');
    }
    lineas.add('${valores.join(' + ')} = $total');
    return lineas;
  }

  /// "E = 14 · F = 15" para las letras hex que aparecen; null si no hay.
  static String? _equivalencias(String texto) {
    final letras = <String>[];
    for (final c in texto.split('')) {
      if (_hexDigitos.indexOf(c) >= 10 && !letras.contains(c)) letras.add(c);
    }
    if (letras.isEmpty) return null;
    return letras
        .map((l) => '\\text{$l} = ${_hexDigitos.indexOf(l)}')
        .join(' \\quad ');
  }

  /// Parte decimal exacta de residuo/8 (1/8=125, 2/8=25, 3/8=375...).
  static String _decimalDeResiduo(int residuo) {
    final milesimas = (residuo * 1000) ~/ 8;
    var s = milesimas.toString().padLeft(3, '0');
    s = s.replaceAll(RegExp(r'0+$'), '');
    return s.isEmpty ? '0' : s;
  }

  static int _bitsNecesarios(int valor) {
    var bits = 1;
    while ((1 << bits) <= valor) {
      bits++;
    }
    while (bits % 4 != 0) {
      bits++;
    }
    return bits;
  }

  static String _binarioAgrupado(int valor, int bits) {
    final sb = StringBuffer();
    for (var i = bits - 1; i >= 0; i--) {
      sb.write(((valor >> i) & 1) == 1 ? '1' : '0');
      if (i % 4 == 0 && i != 0) sb.write(' ');
    }
    return sb.toString();
  }
}
