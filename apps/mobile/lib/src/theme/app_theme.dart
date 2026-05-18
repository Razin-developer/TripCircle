import 'package:flutter/material.dart';

class TripThemePalette {
  const TripThemePalette({
    required this.name,
    required this.background,
    required this.card,
    required this.text,
    required this.subtleText,
    required this.accent,
    required this.marker,
    required this.border,
    required this.shadow,
  });

  final String name;
  final Color background;
  final Color card;
  final Color text;
  final Color subtleText;
  final Color accent;
  final Color marker;
  final Color border;
  final Color shadow;
}

Color _hex(String value) {
  final sanitized = value.replaceAll('#', '');
  return Color(int.parse('FF$sanitized', radix: 16));
}

final Map<String, TripThemePalette> tripThemes = {
  'Midnight': TripThemePalette(name: 'Midnight', background: _hex('#0E1320'), card: _hex('#182033'), text: _hex('#F5F7FB'), subtleText: _hex('#AAB6D2'), accent: _hex('#86A8FF'), marker: _hex('#8DB0FF'), border: _hex('#22304B'), shadow: _hex('#091224')),
  'Ocean': TripThemePalette(name: 'Ocean', background: _hex('#EEF7FB'), card: _hex('#F9FCFE'), text: _hex('#153047'), subtleText: _hex('#62829A'), accent: _hex('#2F8CBF'), marker: _hex('#257FAF'), border: _hex('#D5E7F1'), shadow: _hex('#1E678F')),
  'Forest': TripThemePalette(name: 'Forest', background: _hex('#EFF6F1'), card: _hex('#F9FCFA'), text: _hex('#183126'), subtleText: _hex('#66806F'), accent: _hex('#2D8C63'), marker: _hex('#327A57'), border: _hex('#D5E4DA'), shadow: _hex('#1D5539')),
  'Sunset': TripThemePalette(name: 'Sunset', background: _hex('#FFF3ED'), card: _hex('#FFFBF8'), text: _hex('#45221D'), subtleText: _hex('#8B675E'), accent: _hex('#FF8258'), marker: _hex('#F36E42'), border: _hex('#F7DDD2'), shadow: _hex('#C05831')),
  'Lavender': TripThemePalette(name: 'Lavender', background: _hex('#F6F0FB'), card: _hex('#FCFAFE'), text: _hex('#302343'), subtleText: _hex('#7C6D91'), accent: _hex('#9B7AF7'), marker: _hex('#8E66F5'), border: _hex('#E5D8F5'), shadow: _hex('#7C59C7')),
  'Graphite': TripThemePalette(name: 'Graphite', background: _hex('#F4F4F5'), card: _hex('#FFFFFF'), text: _hex('#1D1D20'), subtleText: _hex('#6E7077'), accent: _hex('#4C5D73'), marker: _hex('#465A71'), border: _hex('#E5E6EA'), shadow: _hex('#232A38')),
  'Mint': TripThemePalette(name: 'Mint', background: _hex('#ECFBF7'), card: _hex('#FAFEFD'), text: _hex('#13312B'), subtleText: _hex('#64877F'), accent: _hex('#25B89B'), marker: _hex('#1FA589'), border: _hex('#D3EEE6'), shadow: _hex('#1A8C75')),
  'Rose': TripThemePalette(name: 'Rose', background: _hex('#FFF0F4'), card: _hex('#FFF9FB'), text: _hex('#44212A'), subtleText: _hex('#916977'), accent: _hex('#E76D96'), marker: _hex('#D85A85'), border: _hex('#F3D8E1'), shadow: _hex('#BE5277')),
  'Sky': TripThemePalette(name: 'Sky', background: _hex('#EEF6FF'), card: _hex('#FAFCFF'), text: _hex('#17324E'), subtleText: _hex('#67839D'), accent: _hex('#4A9FFF'), marker: _hex('#3C8DEA'), border: _hex('#D5E6F9'), shadow: _hex('#3E7FCF')),
  'Sand': TripThemePalette(name: 'Sand', background: _hex('#FBF6EE'), card: _hex('#FFFCF8'), text: _hex('#453A2B'), subtleText: _hex('#8B7B67'), accent: _hex('#C79A5F'), marker: _hex('#B78951'), border: _hex('#EBDDCC'), shadow: _hex('#A27B4A')),
  'Ember': TripThemePalette(name: 'Ember', background: _hex('#FFF2EE'), card: _hex('#FFFBF9'), text: _hex('#49231C'), subtleText: _hex('#9A6A61'), accent: _hex('#E35D47'), marker: _hex('#D64C33'), border: _hex('#F3D6CF'), shadow: _hex('#B24D3B')),
  'Ice': TripThemePalette(name: 'Ice', background: _hex('#F1FBFE'), card: _hex('#FBFEFF'), text: _hex('#15313A'), subtleText: _hex('#67848B'), accent: _hex('#57B8D3'), marker: _hex('#3FA9C7'), border: _hex('#D5EEF4'), shadow: _hex('#3F899E')),
  'Cocoa': TripThemePalette(name: 'Cocoa', background: _hex('#F7F0EC'), card: _hex('#FCFAF8'), text: _hex('#36241D'), subtleText: _hex('#81665B'), accent: _hex('#9B6B56'), marker: _hex('#8E5B43'), border: _hex('#E8D9D0'), shadow: _hex('#765647')),
  'Lime': TripThemePalette(name: 'Lime', background: _hex('#F6FCEB'), card: _hex('#FDFFF8'), text: _hex('#243513'), subtleText: _hex('#76855F'), accent: _hex('#90C43E'), marker: _hex('#7BB130'), border: _hex('#E2EDCD'), shadow: _hex('#668F28')),
  'Violet': TripThemePalette(name: 'Violet', background: _hex('#F5F1FE'), card: _hex('#FCFBFF'), text: _hex('#2A2145'), subtleText: _hex('#776A9B'), accent: _hex('#7865F2'), marker: _hex('#6B56E5'), border: _hex('#E1D8F9'), shadow: _hex('#604FBC')),
  'Peach': TripThemePalette(name: 'Peach', background: _hex('#FFF4EE'), card: _hex('#FFFDFB'), text: _hex('#4B2D23'), subtleText: _hex('#9A766A'), accent: _hex('#F39A77'), marker: _hex('#ED875F'), border: _hex('#F7DECF'), shadow: _hex('#C27853')),
  'Slate': TripThemePalette(name: 'Slate', background: _hex('#F2F5F8'), card: _hex('#FDFEFF'), text: _hex('#1D2B39'), subtleText: _hex('#6A7B8C'), accent: _hex('#5B7A99'), marker: _hex('#506E8C'), border: _hex('#DDE5ED'), shadow: _hex('#3C546D')),
  'Aurora': TripThemePalette(name: 'Aurora', background: _hex('#EFFAF9'), card: _hex('#FBFEFE'), text: _hex('#183238'), subtleText: _hex('#66818A'), accent: _hex('#38B0A2'), marker: _hex('#2A9A8F'), border: _hex('#D4EDE9'), shadow: _hex('#2D8177')),
  'Mono': TripThemePalette(name: 'Mono', background: _hex('#F2F2F2'), card: _hex('#FFFFFF'), text: _hex('#161616'), subtleText: _hex('#767676'), accent: _hex('#2C2C2C'), marker: _hex('#1E1E1E'), border: _hex('#E6E6E6'), shadow: _hex('#1C1C1C')),
  'Classic': TripThemePalette(name: 'Classic', background: _hex('#F6F7FB'), card: _hex('#FFFFFF'), text: _hex('#1B2430'), subtleText: _hex('#6D7683'), accent: _hex('#4E7BFF'), marker: _hex('#5B8DEF'), border: _hex('#E5EAF2'), shadow: _hex('#254884')),
};

List<String> get themeNames => tripThemes.keys.toList(growable: false);

TripThemePalette resolveTheme(String? name) {
  return tripThemes[name] ?? tripThemes['Classic']!;
}

ThemeData buildThemeData(TripThemePalette palette) {
  final scheme = ColorScheme.light(
    primary: palette.accent,
    surface: palette.card,
    onSurface: palette.text,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    useMaterial3: true,
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: palette.text,
          displayColor: palette.text,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
