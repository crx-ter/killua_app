import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/herramienta_scaffold.dart';
import '../../core/widgets/opcion_ajuste.dart';
import 'ia_ajustes_screen.dart';
import 'personalizacion_screen.dart';
import 'seguridad_screen.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => pantalla,
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'Ajustes',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                OpcionAjuste(
                  icono: Icons.lock_outline,
                  titulo: 'Seguridad',
                  subtitulo: 'Contraseña de acceso',
                  onTap: () => _abrir(context, const SeguridadScreen()),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                OpcionAjuste(
                  icono: Icons.color_lens_outlined,
                  titulo: 'Personalización',
                  subtitulo: 'Fondos, temas y lectura',
                  onTap: () => _abrir(context, const PersonalizacionScreen()),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                OpcionAjuste(
                  icono: Icons.auto_awesome_outlined,
                  titulo: 'IA',
                  subtitulo: 'Proveedores, API keys y modelos',
                  onTap: () => _abrir(context, const IaAjustesScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
