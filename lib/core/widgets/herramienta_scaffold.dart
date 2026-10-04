import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_config_service.dart';

class HerramientaScaffold extends StatelessWidget {
  final String titulo;
  final Widget child;
  final List<Widget>? acciones;
  final VoidCallback? alVolver;
  final Widget? barraInferior;

  const HerramientaScaffold({
    super.key,
    required this.titulo,
    required this.child,
    this.acciones,
    this.alVolver,
    this.barraInferior,
  });

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);

    return Scaffold(
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: themeConfig.currentTextColor,
                          size: 20,
                        ),
                        onPressed:
                            alVolver ?? () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          titulo,
                          style: TextStyle(
                            color: themeConfig.currentTextColor,
                            fontSize: 20 + themeConfig.fontSizeDelta,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      if (acciones?.isNotEmpty ?? false) ...acciones!,
                    ],
                  ),
                ),
                Expanded(child: child),
                if (barraInferior != null) barraInferior!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
