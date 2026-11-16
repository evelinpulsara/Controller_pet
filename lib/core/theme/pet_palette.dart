import 'package:flutter/material.dart';

class PetPalette {
  static const mint = Color(0xFF2FB592);
  static const sky = Color(0xFF4C8DF6);
  static const peach = Color(0xFFFF8A4C);
  static const lavender = Color(0xFF8F6EEB);
  static const bubblegum = Color(0xFFEC5B9C);
  static const honey = Color(0xFFE0A21B);

  static const all = [mint, sky, peach, lavender, bubblegum, honey];
  static const defaultColor = mint;

  static String name(Color c, bool es) {
    final i = all.indexWhere((x) => x.toARGB32() == c.toARGB32());
    const esNames = ['Menta', 'Cielo', 'Durazno', 'Lavanda', 'Chicle', 'Miel'];
    const enNames = ['Mint', 'Sky', 'Peach', 'Lavender', 'Bubblegum', 'Honey'];
    if (i < 0) return '';
    return es ? esNames[i] : enNames[i];
  }
}
