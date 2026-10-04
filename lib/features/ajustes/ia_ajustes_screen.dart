import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/herramienta_scaffold.dart';
import '../../services/ia_config_service.dart';
import '../../services/ia_orquestador_service.dart';

class IaAjustesScreen extends StatefulWidget {
  const IaAjustesScreen({super.key});

  @override
  State<IaAjustesScreen> createState() => _IaAjustesScreenState();
}

class _IaAjustesScreenState extends State<IaAjustesScreen> {
  final _openRouterCtrl = TextEditingController();
  final _googleStudioCtrl = TextEditingController();
  final _siliconFlowCtrl = TextEditingController();
  bool _ocultar = true;
  bool _cargando = true;
  bool _probando = false;
  String? _estado;
  bool _estadoOk = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _openRouterCtrl.dispose();
    _googleStudioCtrl.dispose();
    _siliconFlowCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final c = await IaConfigService.leer();
    final openRouter = c.proveedores.firstWhere(
      (p) => p.proveedor == IaProveedor.openRouter,
    );
    final googleStudio = c.proveedores.firstWhere(
      (p) => p.proveedor == IaProveedor.googleStudio,
    );
    final siliconFlow = c.proveedores.firstWhere(
      (p) => p.proveedor == IaProveedor.siliconFlow,
    );
    if (!mounted) return;
    setState(() {
      _openRouterCtrl.text = openRouter.apiKey;
      _googleStudioCtrl.text = googleStudio.apiKey;
      _siliconFlowCtrl.text = siliconFlow.apiKey;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    await IaConfigService.guardar(
      openRouterKey: _openRouterCtrl.text,
      googleStudioKey: _googleStudioCtrl.text,
      siliconFlowKey: _siliconFlowCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _estado = 'Guardado';
      _estadoOk = true;
    });
  }

  Future<void> _probar() async {
    FocusScope.of(context).unfocus();
    await IaConfigService.guardar(
      openRouterKey: _openRouterCtrl.text,
      googleStudioKey: _googleStudioCtrl.text,
      siliconFlowKey: _siliconFlowCtrl.text,
    );
    final config = await IaConfigService.leer();
    final disponibles = config.proveedores.where((p) => p.disponible).toList();
    if (disponibles.isEmpty) {
      setState(() {
        _estado = 'Falta la API key';
        _estadoOk = false;
      });
      return;
    }
    setState(() {
      _probando = true;
      _estado = null;
    });
    final resultados = await Future.wait(
      disponibles.map(
        (proveedor) =>
            IaOrquestadorService.probarProveedor(proveedor: proveedor),
      ),
    );
    final fallidos = <String>[];
    for (var i = 0; i < resultados.length; i++) {
      if (resultados[i] != null) {
        fallidos.add('${disponibles[i].nombre}: ${resultados[i]}');
      }
    }
    if (!mounted) return;
    setState(() {
      _probando = false;
      _estadoOk = fallidos.isEmpty;
      _estado = fallidos.isEmpty
          ? '${disponibles.length} proveedor(es) disponible(s)'
          : fallidos.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'IA',
      child: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _proveedorPanel(
                        nombre: 'OpenRouter',
                        controller: _openRouterCtrl,
                        modelos: IaConfigService.openRouterModelos,
                        hint: 'API key de OpenRouter',
                      ),
                      const SizedBox(height: 20),
                      _proveedorPanel(
                        nombre: 'Google AI Studio',
                        controller: _googleStudioCtrl,
                        modelos: IaConfigService.googleStudioModelos,
                        hint: 'API key de Google AI Studio',
                      ),
                      const SizedBox(height: 20),
                      _proveedorPanel(
                        nombre: 'SiliconFlow',
                        controller: _siliconFlowCtrl,
                        modelos: IaConfigService.siliconFlowModelos,
                        hint: 'API key de SiliconFlow',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _boton(
                  'Probar conexión',
                  _probando ? null : _probar,
                  cargando: _probando,
                ),
                const SizedBox(height: 10),
                _boton('Guardar', _guardar, principal: true),
                if (_estado != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _estado!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _estadoOk
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'El orquestador ignora proveedores sin API key, usa modelos '
                  'de visión para imágenes y cambia de proveedor si falla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _proveedorPanel({
    required String nombre,
    required TextEditingController controller,
    required List<IaModelo> modelos,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(nombre.toUpperCase()),
        const SizedBox(height: 10),
        _campo(
          controller: controller,
          hint: hint,
          oculto: _ocultar,
          sufijo: IconButton(
            icon: Icon(
              _ocultar
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            onPressed: () => setState(() => _ocultar = !_ocultar),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: modelos
              .map(
                (modelo) => _chip(
                  '${modelo.id}${modelo.vision ? ' · visión' : ''}',
                  true,
                  () {},
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ---------- componentes ----------
  Widget _etiqueta(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 11,
      letterSpacing: 3,
    ),
  );

  Widget _chip(String texto, bool activo, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String hint,
    bool oculto = false,
    Widget? sufijo,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: oculto,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: Colors.white,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          suffixIcon: sufijo,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _boton(
    String texto,
    VoidCallback? onTap, {
    bool principal = false,
    bool cargando = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: principal ? 0.28 : 0.12),
              Colors.white.withValues(alpha: principal ? 0.08 : 0.03),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: principal ? 0.3 : 0.18),
          ),
        ),
        child: Center(
          child: cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  texto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
