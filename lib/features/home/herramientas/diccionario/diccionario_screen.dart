import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/herramienta_scaffold.dart';

class DiccionarioScreen extends StatefulWidget {
  const DiccionarioScreen({super.key});

  @override
  State<DiccionarioScreen> createState() => _DiccionarioScreenState();
}

class _DiccionarioScreenState extends State<DiccionarioScreen> {
  static const _fuentesKey = 'diccionario_fuentes_web';
  final _busqueda = TextEditingController();
  final Map<String, String> _entradas = {
    'aprender': 'Adquirir conocimiento mediante el estudio o la experiencia.',
    'estudiar': 'Ejercitar el entendimiento para comprender o aprender algo.',
    'método': 'Modo ordenado de proceder para llegar a un resultado.',
  };
  List<String> _fuentes = [];
  String _consulta = '';

  @override
  void initState() {
    super.initState();
    _cargarFuentes();
    _busqueda.addListener(
      () => setState(() => _consulta = _busqueda.text.trim().toLowerCase()),
    );
  }

  Future<void> _cargarFuentes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _fuentes = prefs.getStringList(_fuentesKey) ?? []);
    }
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _resultados => _entradas.entries
      .where((entry) => _consulta.isEmpty || entry.key.contains(_consulta))
      .toList();

  Future<void> _agregarFuente() async {
    final enlace = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Agregar diccionario'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Enlace',
              hintText: 'https://dem.colmex.mx/',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
    if (enlace == null) return;
    final uri = Uri.tryParse(enlace);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final fuentes = {..._fuentes, enlace}.toList();
    await prefs.setStringList(_fuentesKey, fuentes);
    if (mounted) setState(() => _fuentes = fuentes);
  }

  Future<void> _abrirFuente(String enlace) async {
    final uri = Uri.tryParse(enlace);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'Diccionario',
      acciones: [
        IconButton(
          tooltip: 'Agregar diccionario web',
          onPressed: _agregarFuente,
          icon: const Icon(Icons.add_link_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: _busqueda,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar palabra',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _consulta.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _busqueda.clear,
                      icon: const Icon(Icons.clear, color: Colors.white70),
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ..._resultados.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_resultados.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No hay resultados locales.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
            ),
          if (_fuentes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Fuentes web',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            ..._fuentes.map(
              (fuente) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language, color: Colors.white70),
                title: Text(
                  fuente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.white70),
                  onPressed: () => _abrirFuente(fuente),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
