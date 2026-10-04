import 'package:flutter/material.dart';

class Herramienta {
  final String nombre;
  final String descripcion;
  final IconData icono;
  final WidgetBuilder pantalla;

  const Herramienta({
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.pantalla,
  });
}
