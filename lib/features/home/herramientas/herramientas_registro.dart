import 'package:flutter/material.dart';

import 'herramienta.dart';
import 'calculadora/calculadora_screen.dart';
import 'bases/bases_screen.dart';
import 'despejes/despejes_screen.dart';
import 'diccionario/diccionario_screen.dart';

final List<Herramienta> herramientas = [
  Herramienta(
    nombre: 'Calculadora',
    descripcion: 'Científica',
    icono: Icons.calculate_outlined,
    pantalla: (_) => const CalculadoraScreen(),
  ),
  Herramienta(
    nombre: 'Bases',
    descripcion: 'Bin · Oct · Dec · Hex',
    icono: Icons.data_array,
    pantalla: (_) => const BasesScreen(),
  ),
  Herramienta(
    nombre: 'Despejes',
    descripcion: 'Ecuaciones paso a paso',
    icono: Icons.functions,
    pantalla: (_) => const DespejesScreen(),
  ),
  Herramienta(
    nombre: 'Diccionario',
    descripcion: 'Busca y guarda palabras',
    icono: Icons.menu_book_outlined,
    pantalla: (_) => const DiccionarioScreen(),
  ),
];
