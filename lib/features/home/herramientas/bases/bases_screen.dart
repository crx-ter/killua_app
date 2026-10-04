import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/bouncing_widget.dart';
import '../../../../core/widgets/formula.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/herramienta_scaffold.dart';
import 'motor_bases.dart';

class BasesScreen extends StatefulWidget {
  const BasesScreen({super.key});

  @override
  State<BasesScreen> createState() => _BasesScreenState();
}

class _BasesScreenState extends State<BasesScreen> {
  final _controller = TextEditingController();
  Base _origen = Base.decimal;
  Base? _destino;
  String? _error;
  List<BloqueConversion>? _bloques;
  String _aviso = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Set<Base> get _destinosActivos =>
      _destino == null ? Base.values.toSet() : {_destino!};

  void _convertir() {
    FocusScope.of(context).unfocus();
    final error = MotorBases.validar(_controller.text, _origen);
    if (error != null) {
      setState(() {
        _error = error;
        _bloques = null;
        _aviso = '';
      });
      return;
    }
    final bloques = MotorBases.convertir(
      entrada: _controller.text,
      origen: _origen,
      destinos: _destinosActivos,
    );
    setState(() {
      _error = null;
      _bloques = bloques;
      _aviso = bloques.isEmpty
          ? 'El origen y el destino son el mismo sistema.'
          : '';
    });
  }

  void _copiar(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiado: $texto'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white.withValues(alpha: 0.15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'Bases',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _etiqueta('DE'),
                const SizedBox(height: 10),
                _selectorBase(
                  seleccion: _origen,
                  onChange: (base) => setState(() {
                    _origen = base;
                    _error = null;
                    _bloques = null;
                  }),
                ),
                const SizedBox(height: 16),
                _campo(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _etiqueta('A'),
                const SizedBox(height: 10),
                _selectorBase(
                  seleccion: _destino,
                  conTodos: true,
                  onChange: (base) => setState(() {
                    _destino = base;
                    _bloques = null;
                  }),
                  onTodos: () => setState(() {
                    _destino = null;
                    _bloques = null;
                  }),
                ),
                const SizedBox(height: 18),
                _botonConvertir(),
              ],
            ),
          ),
          if (_aviso.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                _aviso,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (_bloques != null)
            ..._bloques!.map(
              (bloque) => Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _tarjetaBloque(bloque),
              ),
            ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) => Text(
    texto,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 11,
      letterSpacing: 3,
    ),
  );

  Widget _seccion(String texto) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      texto,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 11,
        letterSpacing: 3,
      ),
    ),
  );

  Widget _selectorBase({
    required Base? seleccion,
    required ValueChanged<Base> onChange,
    bool conTodos = false,
    VoidCallback? onTodos,
  }) {
    Widget chip(String texto, bool activo, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: activo
                  ? Colors.white.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: activo ? 0.45 : 0.15),
              ),
            ),
            child: Text(
              texto,
              style: TextStyle(
                color: Colors.white.withValues(alpha: activo ? 1 : 0.6),
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...Base.values.map(
          (base) => chip(base.corto, seleccion == base, () => onChange(base)),
        ),
        if (conTodos) chip('TODOS', seleccion == null, onTodos!),
      ],
    );
  }

  Widget _campo() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: _controller,
        textCapitalization: TextCapitalization.characters,
        keyboardType: _origen == Base.hexadecimal
            ? TextInputType.visiblePassword
            : TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          letterSpacing: 2,
        ),
        cursorColor: Colors.white,
        onSubmitted: (_) => _convertir(),
        decoration: InputDecoration(
          hintText: 'Ej. ${_ejemplo(_origen)}',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  String _ejemplo(Base base) => switch (base) {
    Base.decimal => '255',
    Base.binario => '1011',
    Base.octal => '377',
    Base.hexadecimal => 'FF',
  };

  Widget _botonConvertir() {
    return BouncingWidget(
      onTap: _convertir,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text(
            'Convertir',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaBloque(BloqueConversion bloque) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bloque.base.nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          _seccion('RESULTADO'),
          InkWell(
            onTap: () => _copiar(bloque.resultado.replaceAll(' ', '')),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bloque.resultado,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
          _seccion('CONVERSIÓN'),
          ...bloque.conversion.map(
            (linea) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Formula(linea, tamano: 17),
            ),
          ),
          _seccion('COMPROBACIÓN'),
          ...bloque.comprobacion.map(
            (linea) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Formula(linea, tamano: 17),
            ),
          ),
        ],
      ),
    );
  }
}
