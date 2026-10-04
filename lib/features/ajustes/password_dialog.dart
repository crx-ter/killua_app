import 'package:flutter/material.dart';

import '../../core/widgets/glass_dialog.dart';
import '../../services/auth_service.dart';

Future<bool?> mostrarDialogoPassword(
  BuildContext context, {
  required bool yaTienePassword,
}) {
  return mostrarGlassDialog<bool>(
    context: context,
    child: _PasswordForm(yaTienePassword: yaTienePassword),
  );
}

class _PasswordForm extends StatefulWidget {
  final bool yaTienePassword;

  const _PasswordForm({required this.yaTienePassword});

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (widget.yaTienePassword) {
      final ok = await AuthService.verificar(_actual.text);
      if (!ok) {
        setState(() => _error = 'La contraseña actual no es correcta');
        return;
      }
    }
    if (_nueva.text.length < 4) {
      setState(() => _error = 'Usa al menos 4 caracteres');
      return;
    }
    if (_nueva.text != _confirmar.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    await AuthService.guardarPassword(_nueva.text);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.yaTienePassword ? 'Cambiar contraseña' : 'Crear contraseña',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.yaTienePassword) ...[
          _campo(_actual, 'Contraseña actual'),
          const SizedBox(height: 10),
        ],
        _campo(_nueva, 'Nueva contraseña'),
        const SizedBox(height: 10),
        _campo(_confirmar, 'Confirmar contraseña'),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _guardar,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _campo(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
