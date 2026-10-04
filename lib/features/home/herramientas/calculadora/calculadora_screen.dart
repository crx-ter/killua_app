import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/herramienta_scaffold.dart';
import 'motor_calculadora.dart';

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  String _expr = '';
  String _resultado = '';
  double _ans = 0;
  bool _grados = true;
  bool _segunda = false;
  bool _cientifica = true;
  bool _error = false;
  final List<String> _historial = [];

  void _agregar(String texto) {
    HapticFeedback.selectionClick();
    setState(() {
      _expr += texto;
      _error = false;
      _actualizarVistaPrevia();
    });
  }

  void _agregarFuncion(String nombre) => _agregar('$nombre(');

  void _operador(String op) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expr.isEmpty && _resultado.isNotEmpty && !_error) {
        _expr = 'Ans';
      }
      _expr += op;
      _error = false;
      _resultado = '';
    });
  }

  void _borrar() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expr.isEmpty) return;
      const bloques = [
        'Ans',
        'asin(',
        'acos(',
        'atan(',
        'sin(',
        'cos(',
        'tan(',
        'ln(',
        'log(',
        '√(',
      ];
      var quitado = false;
      for (final bloque in bloques) {
        if (_expr.endsWith(bloque)) {
          _expr = _expr.substring(0, _expr.length - bloque.length);
          quitado = true;
          break;
        }
      }
      if (!quitado) _expr = _expr.substring(0, _expr.length - 1);
      _error = false;
      _actualizarVistaPrevia();
    });
  }

  void _limpiarTodo() {
    HapticFeedback.mediumImpact();
    setState(() {
      _expr = '';
      _resultado = '';
      _error = false;
    });
  }

  void _actualizarVistaPrevia() {
    if (_expr.isEmpty) {
      _resultado = '';
      return;
    }
    try {
      final valor = MotorCalculadora(grados: _grados, ans: _ans).evaluar(_expr);
      _resultado = formatearResultado(valor);
    } catch (_) {
      _resultado = '';
    }
  }

  void _igual() {
    HapticFeedback.lightImpact();
    if (_expr.isEmpty) return;
    setState(() {
      try {
        final valor = MotorCalculadora(
          grados: _grados,
          ans: _ans,
        ).evaluar(_expr);
        final texto = formatearResultado(valor);
        _historial.insert(0, '$_expr = $texto');
        if (_historial.length > 30) _historial.removeLast();
        _ans = valor;
        _resultado = texto;
        _expr = '';
        _error = false;
      } on ErrorCalculo catch (e) {
        _resultado = e.mensaje;
        _error = true;
      }
    });
  }

  void _mostrarHistorial() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          child: SizedBox(
            height: 320,
            child: _historial.isEmpty
                ? Center(
                    child: Text(
                      'Sin historial',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _historial.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.white.withValues(alpha: 0.08)),
                    itemBuilder: (_, i) => Text(
                      _historial[i],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'Calculadora',
      acciones: [
        IconButton(
          onPressed: _mostrarHistorial,
          icon: Icon(
            Icons.history,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
      child: Column(
        children: [
          _pantalla(),
          _barraModos(),
          Expanded(child: _teclado()),
        ],
      ),
    );
  }

  Widget _pantalla() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SizedBox(
          height: 118,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  scrollDirection: Axis.horizontal,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _expr.isEmpty ? ' ' : _expr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _resultado.isEmpty ? '0' : _resultado,
                  style: TextStyle(
                    color: _error ? Colors.redAccent : Colors.white,
                    fontSize: _error ? 24 : 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraModos() {
    Widget chip(String texto, bool activo, VoidCallback onTap) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: activo
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: Colors.white.withValues(alpha: activo ? 0.4 : 0.15),
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: Colors.white.withValues(alpha: activo ? 1 : 0.6),
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chip(_grados ? 'DEG' : 'RAD', true, () {
            setState(() {
              _grados = !_grados;
              _actualizarVistaPrevia();
            });
          }),
          const SizedBox(width: 8),
          if (_cientifica)
            chip('2nd', _segunda, () => setState(() => _segunda = !_segunda)),
          const Spacer(),
          chip(_cientifica ? 'Científica' : 'Básica', false, () {
            setState(() => _cientifica = !_cientifica);
          }),
        ],
      ),
    );
  }

  Widget _teclado() {
    final sci = <List<_Tecla>>[
      [
        _Tecla(
          _segunda ? 'sin⁻¹' : 'sin',
          () => _agregarFuncion(_segunda ? 'asin' : 'sin'),
          _Tipo.ciencia,
        ),
        _Tecla(
          _segunda ? 'cos⁻¹' : 'cos',
          () => _agregarFuncion(_segunda ? 'acos' : 'cos'),
          _Tipo.ciencia,
        ),
        _Tecla(
          _segunda ? 'tan⁻¹' : 'tan',
          () => _agregarFuncion(_segunda ? 'atan' : 'tan'),
          _Tipo.ciencia,
        ),
        _Tecla('ln', () => _agregarFuncion('ln'), _Tipo.ciencia),
        _Tecla('log', () => _agregarFuncion('log'), _Tipo.ciencia),
      ],
      [
        _Tecla.icono(
          Icons.calculate_outlined,
          () => _agregar('√('),
          _Tipo.ciencia,
        ),
        _Tecla('x²', () => _agregar('^2'), _Tipo.ciencia),
        _Tecla('xʸ', () => _agregar('^'), _Tipo.ciencia),
        _Tecla('x!', () => _agregar('!'), _Tipo.ciencia),
        _Tecla('%', () => _agregar('%'), _Tipo.ciencia),
      ],
      [
        _Tecla('π', () => _agregar('π'), _Tipo.ciencia),
        _Tecla('e', () => _agregar('e'), _Tipo.ciencia),
        _Tecla('Ans', () => _agregar('Ans'), _Tipo.ciencia),
        _Tecla('(', () => _agregar('('), _Tipo.ciencia),
        _Tecla(')', () => _agregar(')'), _Tipo.ciencia),
      ],
    ];

    final basico = <List<_Tecla>>[
      [
        _Tecla('C', _limpiarTodo, _Tipo.accion),
        _Tecla.icono(Icons.backspace_outlined, _borrar, _Tipo.accion),
        _cientifica
            ? _Tecla('%', () => _agregar('%'), _Tipo.accion)
            : _Tecla('( )', () {
                final abiertos = '('.allMatches(_expr).length;
                final cerrados = ')'.allMatches(_expr).length;
                _agregar(abiertos > cerrados ? ')' : '(');
              }, _Tipo.accion),
        _Tecla('÷', () => _operador('÷'), _Tipo.operador),
      ],
      [
        _Tecla('7', () => _agregar('7'), _Tipo.numero),
        _Tecla('8', () => _agregar('8'), _Tipo.numero),
        _Tecla('9', () => _agregar('9'), _Tipo.numero),
        _Tecla('×', () => _operador('×'), _Tipo.operador),
      ],
      [
        _Tecla('4', () => _agregar('4'), _Tipo.numero),
        _Tecla('5', () => _agregar('5'), _Tipo.numero),
        _Tecla('6', () => _agregar('6'), _Tipo.numero),
        _Tecla('−', () => _operador('−'), _Tipo.operador),
      ],
      [
        _Tecla('1', () => _agregar('1'), _Tipo.numero),
        _Tecla('2', () => _agregar('2'), _Tipo.numero),
        _Tecla('3', () => _agregar('3'), _Tipo.numero),
        _Tecla('+', () => _operador('+'), _Tipo.operador),
      ],
      [
        _Tecla('0', () => _agregar('0'), _Tipo.numero),
        _Tecla('.', () => _agregar('.'), _Tipo.numero),
        _Tecla('EXP', () => _agregar('E'), _Tipo.accion),
        _Tecla('=', _igual, _Tipo.igual),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          if (_cientifica)
            ...sci.map((fila) => Expanded(child: _fila(fila, compacta: true))),
          ...basico.map((fila) => Expanded(child: _fila(fila))),
        ],
      ),
    );
  }

  Widget _fila(List<_Tecla> teclas, {bool compacta = false}) {
    return Row(
      children: teclas.map((tecla) {
        return Expanded(child: _botonTecla(tecla, compacta));
      }).toList(),
    );
  }

  Widget _botonTecla(_Tecla tecla, bool compacta) {
    Color relleno;
    Color contenido = Colors.white;
    Color borde = Colors.white.withValues(alpha: 0.12);
    FontWeight peso = FontWeight.w400;

    switch (tecla.tipo) {
      case _Tipo.numero:
        relleno = Colors.white.withValues(alpha: 0.07);
      case _Tipo.operador:
        relleno = Colors.white.withValues(alpha: 0.16);
        borde = Colors.white.withValues(alpha: 0.28);
        peso = FontWeight.w500;
      case _Tipo.accion:
        relleno = Colors.white.withValues(alpha: 0.04);
        contenido = Colors.white.withValues(alpha: 0.75);
      case _Tipo.ciencia:
        relleno = Colors.white.withValues(alpha: 0.03);
        contenido = Colors.white.withValues(alpha: 0.7);
      case _Tipo.igual:
        relleno = Colors.white.withValues(alpha: 0.30);
        borde = Colors.white.withValues(alpha: 0.5);
        peso = FontWeight.w600;
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compacta ? 14 : 20),
          onTap: tecla.accion,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compacta ? 14 : 20),
              color: relleno,
              border: Border.all(color: borde),
            ),
            child: Center(
              child: tecla.icono != null
                  ? Icon(
                      tecla.icono,
                      color: contenido,
                      size: compacta ? 20 : 26,
                    )
                  : FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          tecla.etiqueta!,
                          style: TextStyle(
                            color: contenido,
                            fontSize: compacta ? 15 : 24,
                            fontWeight: peso,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Tipo { numero, operador, accion, ciencia, igual }

class _Tecla {
  final String? etiqueta;
  final IconData? icono;
  final VoidCallback accion;
  final _Tipo tipo;

  _Tecla(this.etiqueta, this.accion, this.tipo) : icono = null;

  _Tecla.icono(this.icono, this.accion, this.tipo) : etiqueta = null;
}
