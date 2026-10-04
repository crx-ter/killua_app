import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/bouncing_widget.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/herramienta_scaffold.dart';
import '../../services/theme_config_service.dart';
import '../../services/asset_service.dart';

class PersonalizacionScreen extends StatefulWidget {
  const PersonalizacionScreen({super.key});

  @override
  State<PersonalizacionScreen> createState() => _PersonalizacionScreenState();
}

class _PersonalizacionScreenState extends State<PersonalizacionScreen> {
  List<String> _fondosDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarFondos();
  }

  Future<void> _cargarFondos() async {
    final fondos = await AssetService.obtenerFondosDisponibles();
    if (mounted) {
      setState(() {
        _fondosDisponibles = fondos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);

    return HerramientaScaffold(
      titulo: 'Personalización',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSeccion(
            titulo: 'Fondos dinámicos',
            child: _buildFondosSelector(themeConfig),
          ),
          const SizedBox(height: 20),
          _buildSeccion(
            titulo: 'Efecto Liquid Glass',
            child: _buildGlassConfig(themeConfig),
          ),
          const SizedBox(height: 20),
          _buildSeccion(
            titulo: 'Texto y Lectura',
            child: _buildTextConfig(themeConfig),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion({required String titulo, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        GlassCard(padding: const EdgeInsets.all(16), child: child),
      ],
    );
  }

  Widget _buildFondosSelector(ThemeConfigService theme) {
    if (_fondosDisponibles.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Imágenes', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _fondosDisponibles.length,
            itemBuilder: (ctx, i) {
              final path = _fondosDisponibles[i];
              final isSelected = theme.fondoPath == path;
              return BouncingWidget(
                onTap: () => theme.setFondoPath(path),
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.greenAccent
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      width: 70,
                      height: 100,
                      // Decodifica solo a 140×200px en RAM, no a resolución completa
                      cacheWidth: 140,
                      cacheHeight: 200,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text('Fondos sólidos', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSolidBgOption(theme, 'solid_black', Colors.black, 'Negro'),
            const SizedBox(width: 12),
            _buildSolidBgOption(theme, 'solid_white', Colors.white, 'Blanco'),
          ],
        ),
      ],
    );
  }

  Widget _buildSolidBgOption(
    ThemeConfigService theme,
    String path,
    Color color,
    String label,
  ) {
    final isSelected = theme.fondoPath == path;
    return GestureDetector(
      onTap: () => theme.setFondoPath(path),
      child: Container(
        height: 60,
        width: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : Colors.grey,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color == Colors.black ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassConfig(ThemeConfigService theme) {
    final colors = [
      Colors.white,
      Colors.grey.shade900,
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.deepPurpleAccent,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color base', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final isSelected = theme.glassColor == c;
            return GestureDetector(
              onTap: () => theme.setGlassColor(c),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.greenAccent : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Opacidad del efecto', style: TextStyle(fontSize: 14)),
        Slider(
          value: theme.glassOpacity,
          min: 0.0,
          max: 0.8,
          activeColor: Colors.greenAccent,
          onChanged: (v) => theme.setGlassOpacityPreview(v),
          onChangeEnd: (v) => theme.setGlassOpacity(v),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Líneas de alto contraste'),
            Switch(
              value: theme.highContrastLines,
              activeThumbColor: Colors.greenAccent,
              onChanged: (v) => theme.setHighContrastLines(v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextConfig(ThemeConfigService theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tamaño de letra', style: TextStyle(fontSize: 14)),
        Slider(
          value: theme.fontSizeDelta,
          min: 0.0,
          max: 12.0,
          divisions: 6,
          label: '+${theme.fontSizeDelta.toInt()}px',
          activeColor: Colors.greenAccent,
          onChanged: (v) => theme.setFontSizeDeltaPreview(v),
          onChangeEnd: (v) => theme.setFontSizeDelta(v),
        ),
        const SizedBox(height: 16),
        const Text('Contraste de texto', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildTextModeOption(theme, null, 'Automático'),
            _buildTextModeOption(
              theme,
              Colors.white.withValues(alpha: 0.92),
              'Claro',
            ),
            _buildTextModeOption(theme, Colors.black87, 'Oscuro'),
          ],
        ),
      ],
    );
  }

  Widget _buildTextModeOption(
    ThemeConfigService theme,
    Color? color,
    String label,
  ) {
    final isSelected = theme.overrideTextColor == color;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.greenAccent.withValues(alpha: 0.2),
      onSelected: (_) => theme.setOverrideTextColor(color),
    );
  }
}
