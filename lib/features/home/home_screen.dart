import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/bouncing_widget.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/theme_config_service.dart';
import '../ajustes/ajustes_screen.dart';
import '../drive/drive_screen.dart';
import '../ia/ia_screen.dart';
import '../drive/datos/drive_repositorio.dart';
import '../drive/modelos/drive_elemento.dart';
import '../drive/notas/nota_editor_screen.dart';
import '../drive/documentos/visor_documento_screen.dart';
import 'herramientas/herramientas_registro.dart';

import 'calendario/calendario_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;
  final _driveRepositorio = DriveRepositorio();
  late Future<List<DriveElemento>> _favoritosFuture;
  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  void _cargarFavoritos() {
    _favoritosFuture = _driveRepositorio.listarFavoritos();
  }

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.build_outlined, Icons.build, 'Herramientas'),
    (Icons.folder_outlined, Icons.folder, 'Drive'),
  ];

  void _abrir(Widget pantalla) {
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, _, _) => pantalla,
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        )
        .then((_) {
          if (mounted) {
            setState(_cargarFavoritos);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfigService>(context);

    return Scaffold(
      extendBody: true,
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
                _barraSuperior(themeConfig),
                Expanded(child: _contenido()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _barraGlass(themeConfig),
    );
  }

  Widget _contenido() {
    return switch (_indice) {
      0 => _inicio(),
      1 => _herramientas(),
      _ => DriveScreen(repositorio: _driveRepositorio),
    };
  }

  Widget _inicio() {
    final themeConfig = Provider.of<ThemeConfigService>(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      children: [
        Text(
          'Tu espacio de estudio',
          style: TextStyle(
            color: themeConfig.currentTextColor,
            fontSize: 28,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Guarda, organiza y vuelve a lo que estás aprendiendo.',
          style: TextStyle(
            color: themeConfig.currentTextColor.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 22),
        _seccionTitulo('Tu espacio personal'),
        const SizedBox(height: 10),
        FutureBuilder<List<DriveElemento>>(
          future: _favoritosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.push_pin_outlined,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Aún no hay favoritos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aquí aparecerán tus temas fijados desde Drive.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final favoritos = snapshot.data!;
            return Column(
              children: favoritos.map((fav) {
                IconData icono = Icons.insert_drive_file_outlined;
                if (fav.tipo == TipoElementoDrive.carpeta) {
                  icono = Icons.folder_outlined;
                }
                if (fav.tipo == TipoElementoDrive.nota) {
                  icono = Icons.description_outlined;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: Icon(icono, color: Colors.amberAccent),
                      title: Text(
                        fav.nombre,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.star,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onTap: () async {
                        if (fav.tipo == TipoElementoDrive.carpeta) {
                          // Navegar a la carpeta empujando un nuevo DriveScreen
                          // Primero calculamos la ruta para que funcionen las migas de pan
                          final ruta = await _driveRepositorio.rutaDe(fav.id);
                          if (!mounted) return;
                          _abrir(
                            Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                iconTheme: const IconThemeData(
                                  color: Colors.white,
                                ),
                              ),
                              body: SafeArea(
                                child: DriveScreen(
                                  repositorio: _driveRepositorio,
                                  carpetaInicialId: fav.id,
                                  rutaInicial: ruta,
                                ),
                              ),
                            ),
                          );
                        } else if (fav.tipo == TipoElementoDrive.nota) {
                          _abrir(
                            NotaEditorScreen(
                              nota: fav,
                              repositorio: _driveRepositorio,
                            ),
                          );
                        } else if (fav.tipo == TipoElementoDrive.documento) {
                          await _abrirDocumento(fav);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        const CalendarioWidget(),
      ],
    );
  }

  Future<void> _abrirDocumento(DriveElemento documento) async {
    final rutaRelativa = documento.rutaRelativa;
    if (rutaRelativa == null) return;

    try {
      final archivo = await _driveRepositorio.archivoDeDocumento(rutaRelativa);
      if (!await archivo.exists() || !mounted) return;
      _abrir(VisorDocumentoScreen(elemento: documento, archivo: archivo));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento.')),
        );
      }
    }
  }

  Widget _herramientas() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: herramientas.length,
      itemBuilder: (context, i) {
        final herramienta = herramientas[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BouncingWidget(
            onTap: () => _abrir(herramienta.pantalla(context)),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    herramienta.icono,
                    size: 32,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        herramienta.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        herramienta.descripcion,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _seccionTitulo(String texto) => Text(
    texto,
    style: TextStyle(
      color: Provider.of<ThemeConfigService>(context).currentTextColor
          .withValues(alpha: 0.65),
      fontSize: 12,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _barraSuperior(ThemeConfigService themeConfig) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 12, 0),
      child: Row(
        children: [
          Text(
            'KILLUA',
            style: TextStyle(
              fontFamily: 'monospace',
              color: themeConfig.currentTextColor.withValues(alpha: 0.35),
              fontSize: 14,
              letterSpacing: 8,
            ),
          ),
          const Spacer(),
          BouncingWidget(
            onTap: () => _abrir(const IaScreen()),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.auto_awesome_outlined,
                color: themeConfig.currentTextColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 4),
          BouncingWidget(
            onTap: () => _abrir(const AjustesScreen()),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.settings_outlined,
                color: themeConfig.currentTextColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraGlass(ThemeConfigService themeConfig) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 0, 60, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: themeConfig.glassColor.withValues(
                alpha: themeConfig.glassOpacity,
              ),
              border: Border.all(color: themeConfig.currentLineColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                final activo = i == _indice;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == 0 && _indice != 0) {
                      _cargarFavoritos();
                    }
                    setState(() => _indice = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: activo
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          activo ? _items[i].$2 : _items[i].$1,
                          color: activo
                              ? themeConfig.currentTextColor
                              : themeConfig.currentTextColor.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: activo
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: activo
                                ? themeConfig.currentTextColor
                                : themeConfig.currentTextColor.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
