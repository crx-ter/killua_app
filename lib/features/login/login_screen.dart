import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/bouncing_widget.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/theme_config_service.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  bool _ocultar = true;
  bool _error = false;
  bool _cargandoAuth = true;
  bool _tienePassword = true;

  @override
  void initState() {
    super.initState();
    _verificarAuth();
  }

  Future<void> _verificarAuth() async {
    final tiene = await AuthService.tienePassword();
    if (mounted) {
      setState(() {
        _tienePassword = tiene;
        _cargandoAuth = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_tienePassword) {
      // Sin contraseña, entra directo
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }

    final ok = await AuthService.verificar(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeConfig = Provider.of<ThemeConfigService>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (themeConfig.isSolidBlack)
            Container(color: Colors.black)
          else if (themeConfig.isSolidWhite)
            Container(color: Colors.white)
          else
            Image.asset(themeConfig.fondoPath, fit: BoxFit.cover),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.vertical,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/imagenes_app/logotipo_1.png',
                      width: 150,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'KILLUA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TU MUNDO. EN UN SOLO LUGAR.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 40),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tienePassword
                                ? 'Accede a tu cuenta'
                                : 'Bienvenido',
                            style: TextStyle(
                              color: themeConfig.currentTextColor,
                              fontSize: 19 + themeConfig.fontSizeDelta,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_tienePassword) ...[
                            _campoPassword(themeConfig),
                            const SizedBox(height: 18),
                          ],
                          _botonEntrar(themeConfig),
                          const SizedBox(height: 22),
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  _tienePassword
                                      ? Icons.verified_user_outlined
                                      : Icons.waving_hand_outlined,
                                  size: 20,
                                  color: themeConfig.currentTextColor
                                      .withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _tienePassword ? 'Tu cuenta está protegida.' : 'Puedes configurar una contraseña en Ajustes.',
                                  style: TextStyle(
                                    color: themeConfig.currentTextColor
                                        .withValues(alpha: 0.75),
                                    fontSize: 12 + themeConfig.fontSizeDelta,
                                  ),
                                ),
                                if (_tienePassword) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _error
                                        ? 'Contraseña incorrecta. Intenta de nuevo.'
                                        : 'Ingresa tu contraseña para continuar.',
                                    style: TextStyle(
                                      color: _error
                                          ? Colors.redAccent
                                          : themeConfig.currentTextColor
                                                .withValues(alpha: 0.45),
                                      fontSize: 11 + themeConfig.fontSizeDelta,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoPassword(ThemeConfigService themeConfig) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: themeConfig.currentTextColor.withValues(alpha: 0.06),
        border: Border.all(color: themeConfig.currentLineColor),
      ),
      child: TextField(
        controller: _controller,
        obscureText: _ocultar,
        style: TextStyle(color: themeConfig.currentTextColor),
        cursorColor: themeConfig.currentTextColor,
        onSubmitted: (_) => _entrar(),
        decoration: InputDecoration(
          hintText: 'Contraseña',
          hintStyle: TextStyle(
            color: themeConfig.currentTextColor.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.lock_outline,
            color: themeConfig.currentTextColor.withValues(alpha: 0.7),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _ocultar
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: themeConfig.currentTextColor.withValues(alpha: 0.7),
            ),
            onPressed: () => setState(() => _ocultar = !_ocultar),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _botonEntrar(ThemeConfigService themeConfig) {
    return BouncingWidget(
      onTap: _entrar,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeConfig.currentTextColor.withValues(alpha: 0.28),
              themeConfig.currentTextColor.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: themeConfig.currentLineColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Entrar',
              style: TextStyle(
                color: themeConfig.currentTextColor,
                fontSize: 17 + themeConfig.fontSizeDelta,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: themeConfig.currentTextColor),
          ],
        ),
      ),
    );
  }
}
