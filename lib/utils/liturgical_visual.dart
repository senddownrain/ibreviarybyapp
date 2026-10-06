/// One liturgical colour for every screen (port of mybrev
/// `liturgicalVisual.js`).
///
/// The vestment colour comes from the Ordo engine (Latin rubrical names):
/// albus, ruber, viridis, violaceus, rosaceus, niger. It is what the Ordo
/// writes («Колер літургічнага адзення: Белы») and what the Hours, the Ordo
/// month/day, the picker and the option sheets paint with.
///
/// Marian blue is only a secondary, decorative accent of a Marian white
/// celebration; it is never a vestment colour.
library;

import 'package:flutter/material.dart';
import 'package:mybrev_flutter/models/day.dart';

/// Accent themes (text/borders/tints) — contrast-checked in tests.
abstract final class LiturgicalAccents {
  static const white = Color(0xFF8F7D52);
  static const gold = Color(0xFFA77A12);
  static const red = Color(0xFFB33A3A);
  static const green = Color(0xFF4D8A5B);
  static const violet = Color(0xFF7A57A7);
  static const rose = Color(0xFFB5617F);
  static const black = Color(0xFF67546B);

  /// Secondary decorative accent of a Marian (white) celebration.
  static const marian = Color(0xFF4F8FB7);
}

class VestmentColor {
  const VestmentColor({
    required this.key,
    required this.label,
    required this.swatch,
    required this.ring,
    required this.theme,
  });

  /// Latin key (`albus` …).
  final String key;

  /// «Белы», «Чырвоны» …
  final String label;

  /// The fabric colour.
  final Color swatch;

  /// Calendar ring/dot: white is drawn as gold — a white dot would vanish on
  /// a light surface.
  final Color ring;

  /// Accent of the colour itself.
  final Color theme;
}

const kVestmentColors = <String, VestmentColor>{
  'albus': VestmentColor(
    key: 'albus',
    label: 'Белы',
    swatch: Color(0xFFF3ECD9),
    ring: Color(0xFFD2B15F),
    theme: LiturgicalAccents.white,
  ),
  'ruber': VestmentColor(
    key: 'ruber',
    label: 'Чырвоны',
    swatch: Color(0xFFB33A3A),
    ring: Color(0xFFB33A3A),
    theme: LiturgicalAccents.red,
  ),
  'viridis': VestmentColor(
    key: 'viridis',
    label: 'Зялёны',
    swatch: Color(0xFF4D8A5B),
    ring: Color(0xFF4D8A5B),
    theme: LiturgicalAccents.green,
  ),
  'violaceus': VestmentColor(
    key: 'violaceus',
    label: 'Фіялетавы',
    swatch: Color(0xFF7A57A7),
    ring: Color(0xFF7A57A7),
    theme: LiturgicalAccents.violet,
  ),
  'rosaceus': VestmentColor(
    key: 'rosaceus',
    label: 'Ружовы',
    swatch: Color(0xFFD88AA6),
    ring: Color(0xFFD88AA6),
    theme: LiturgicalAccents.rose,
  ),
  'niger': VestmentColor(
    key: 'niger',
    label: 'Чорны',
    swatch: Color(0xFF2F2A30),
    ring: Color(0xFF2F2A30),
    theme: LiturgicalAccents.black,
  ),
};

/// «Колер літургічнага адзення: Белы».
String vestmentLabel(String? color) => kVestmentColors[color]?.label ?? '';

/// What the UI paints a celebration with.
class LiturgicalVisual {
  const LiturgicalVisual({
    required this.vestment,
    required this.accent,
    this.marianAccent = false,
  });

  final VestmentColor vestment;

  /// Tint of the UI: the vestment theme, gold for a white solemnity, Marian
  /// blue for a Marian white celebration.
  final Color accent;

  /// The accent is the secondary Marian blue (vestment stays white).
  final bool marianAccent;

  String get label => vestment.label;
}

const _solemnities = {'solemnitas', 'solemnity'};

/// The single resolver: vestment colour (+ category, rank) → visual.
LiturgicalVisual? liturgicalVisual({
  required String? color,
  String? category,
  String? rank,
}) {
  final vestment = kVestmentColors[color];
  if (vestment == null) return null;
  final marian = color == 'albus' && category == 'mary';
  var accent = vestment.theme;
  if (marian) {
    accent = LiturgicalAccents.marian;
  } else if (color == 'albus' && _solemnities.contains(rank)) {
    accent = LiturgicalAccents.gold;
  }
  return LiturgicalVisual(
    vestment: vestment,
    accent: accent,
    marianAccent: marian,
  );
}

/// Visual of a document stamped by the Hours (`_vestmentColor` …), or null.
LiturgicalVisual? visualOfDay(LiturgicalDay? day) {
  final color = day?.field('_vestmentColor');
  if (color == null) return null;
  return liturgicalVisual(
    color: color,
    category: day?.field('_celebrationCategory'),
    rank: day?.field('_celebrationRank'),
  );
}

/// Calendar ring / dot of a vestment colour.
Color vestmentRing(String color) =>
    (kVestmentColors[color] ?? kVestmentColors['viridis']!).ring;

/// Canonical colour of a period (rows of the picker «Перыяды»).
const kPeriodVestment = {
  'advent': 'violaceus',
  'christmas': 'albus',
  'lent': 'violaceus',
  'holyweek': 'violaceus',
  'easter': 'albus',
  'ordinary': 'viridis',
};
