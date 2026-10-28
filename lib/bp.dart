import 'package:flutter/material.dart';

import 'knit.dart';

class BpCategory {
  final String label;
  final Color color;
  const BpCategory(this.label, this.color);
}

/// Ориентировочная классификация (ESC/ESH) — не диагноз.
BpCategory classify(int sys, int dia) {
  if (sys < 90 || dia < 60) return const BpCategory('Пониженное', Wool.denim);
  if (sys >= 180 || dia >= 110) return const BpCategory('Очень высокое', Color(0xFF8E1B3A));
  if (sys >= 160 || dia >= 100) return const BpCategory('Высокое, 2 ст.', Wool.brick);
  if (sys >= 140 || dia >= 90) return const BpCategory('Высокое, 1 ст.', Color(0xFFD9772E));
  if (sys >= 130 || dia >= 85) return const BpCategory('Высокое нормальное', Wool.mustard);
  if (sys >= 120 || dia >= 80) return const BpCategory('Нормальное', Wool.sage);
  return const BpCategory('Оптимальное', Color(0xFF5E8C61));
}
