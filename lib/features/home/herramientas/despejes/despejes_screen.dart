import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/herramienta_scaffold.dart';

class DespejesScreen extends StatefulWidget {
  const DespejesScreen({super.key});

  @override
  State<DespejesScreen> createState() => _DespejesScreenState();
}

class _DespejesScreenState extends State<DespejesScreen> {
  final _a = TextEditingController(text: '2');
  final _b = TextEditingController(text: '3');
  final _c = TextEditingController(text: '11');
  String _resultado = '';
  String _pasos = '';

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  void _resolver() {
    final a = double.tryParse(_a.text.replaceAll(',', '.'));
    final b = double.tryParse(_b.text.replaceAll(',', '.'));
    final c = double.tryParse(_c.text.replaceAll(',', '.'));
    if (a == null || b == null || c == null || a == 0) {
      setState(() {
        _resultado = 'Revisa los valores. A no puede ser 0.';
        _pasos = '';
      });
      return;
    }

    final x = (c - b) / a;
    setState(() {
      _resultado = 'x = ${_numero(x)}';
      _pasos =
          '${_numero(a)}x + ${_numero(b)} = ${_numero(c)}\n'
          '1. Resta ${_numero(b)} en ambos lados:\n'
          '   ${_numero(a)}x = ${_numero(c - b)}\n'
          '2. Divide entre ${_numero(a)}:\n'
          '   x = ${_numero(c - b)} / ${_numero(a)}';
    });
  }

  String _numero(double valor) => valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toStringAsFixed(4);

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'Despejes',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ecuación lineal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Resuelve Ax + B = C paso a paso.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _campo('A', _a)),
                    _signo('x +'),
                    Expanded(child: _campo('B', _b)),
                    _signo('='),
                    Expanded(child: _campo('C', _c)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _resolver,
                    icon: const Icon(Icons.functions),
                    label: const Text('Resolver'),
                  ),
                ),
              ],
            ),
          ),
          if (_resultado.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resultado',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _resultado,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_pasos.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Pasos',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _pasos,
                      style: const TextStyle(color: Colors.white, height: 1.55),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _campo(String etiqueta, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _signo(String texto) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Text(
      texto,
      style: const TextStyle(color: Colors.white, fontSize: 16),
    ),
  );
}
