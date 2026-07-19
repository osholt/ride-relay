import 'package:flutter/material.dart';

/// Colours a rider can personally choose. Lead, tail end charlie, and the
/// urgent-alert override are never picked from this palette - see
/// [effectiveRiderColor] - so a colour always unambiguously means a role or
/// a specific person, never both.
enum RiderColor { green, orange, yellow, teal, pink, cyan, amber, crimson }

extension RiderColorData on RiderColor {
  Color get color => switch (this) {
    RiderColor.green => const Color(0xFF6ED89A),
    RiderColor.orange => const Color(0xFFFF9F5A),
    RiderColor.yellow => const Color(0xFFE8D24C),
    RiderColor.teal => const Color(0xFF4FC7C7),
    RiderColor.pink => const Color(0xFFE87FC0),
    RiderColor.cyan => const Color(0xFF5AC8FA),
    RiderColor.amber => const Color(0xFFD9A441),
    RiderColor.crimson => const Color(0xFFD9607A),
  };

  String get label => switch (this) {
    RiderColor.green => 'Green',
    RiderColor.orange => 'Orange',
    RiderColor.yellow => 'Yellow',
    RiderColor.teal => 'Teal',
    RiderColor.pink => 'Pink',
    RiderColor.cyan => 'Sky blue',
    RiderColor.amber => 'Amber',
    RiderColor.crimson => 'Crimson',
  };
}

/// Default for sessions created before this feature existed, and the
/// fallback when a peer sends an unrecognised colour name. Matches the
/// green riders have always shown as.
const riderColorDefault = RiderColor.green;

RiderColor riderColorFromName(String? name) => RiderColor.values.firstWhere(
  (value) => value.name == name,
  orElse: () => riderColorDefault,
);

/// Reserved colours that never come from a rider's personal choice: lead,
/// tail end charlie, and the alert override that replaces any rider's colour
/// while they need attention. Kept alongside the palette so a UI can exclude
/// them when offering rider-selectable colours.
const leadColor = Color(0xFFB58CFF);
const tailEndCharlieColor = Color(0xFF68A9FF);
const alertColor = Color(0xFFFF5D73);
