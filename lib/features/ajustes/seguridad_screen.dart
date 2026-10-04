import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/widgets/herramienta_scaffold.dart';
import '../../core/widgets/opcion_ajuste.dart';
import '../../services/auth_service.dart';
import 'password_dialog.dart';

class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  bool _tienePassword = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    final valor = await AuthService.tienePassword();
    if (!mounted) return;
    setState(() {
      _tienePassword = valor;
      _cargando = false;
    });
  }

  Future<void> _crearOCambiar() async {
    final guardo = await mostrarDialogoPassword(
      context,
      yaTienePassword: _tienePassword,
    );
    if (guardo == true) {
      await _cargarEstado();
      _aviso('Contraseña guardada');
    }
  }

  Future<void> _quitar() async {
    final confirmar = await mostrarGlassDialog<bool>(
      context: context,
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quitar contraseña',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La app entrará directo al inicio, sin pedir contraseña.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Quitar',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmar == true) {
      await AuthService.eliminarPassword();
      await _cargarEstado();
      _aviso('Contraseña eliminada');
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HerramientaScaffold(
      titulo: 'Seguridad',
      child: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      OpcionAjuste(
                        icono: Icons.lock_outline,
                        titulo: _tienePassword
                            ? 'Cambiar contraseña'
                            : 'Crear contraseña',
                        subtitulo: _tienePassword
                            ? 'Protegida con contraseña'
                            : 'Sin contraseña: entra directo',
                        onTap: _crearOCambiar,
                      ),
                      if (_tienePassword) ...[
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        OpcionAjuste(
                          icono: Icons.lock_open_outlined,
                          titulo: 'Quitar contraseña',
                          subtitulo: 'Entrar sin pedir contraseña',
                          onTap: _quitar,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
