import type { ThemeName } from "@/types";

export type AppTheme = {
  name: ThemeName;
  background: string;
  card: string;
  text: string;
  subtleText: string;
  accent: string;
  marker: string;
  border: string;
  shadow: string;
};

const themes: Record<ThemeName, AppTheme> = {
  Midnight: { name: "Midnight", background: "#0E1320", card: "#182033", text: "#F5F7FB", subtleText: "#AAB6D2", accent: "#86A8FF", marker: "#8DB0FF", border: "#22304B", shadow: "rgba(9,18,36,0.24)" },
  Ocean: { name: "Ocean", background: "#EEF7FB", card: "#F9FCFE", text: "#153047", subtleText: "#62829A", accent: "#2F8CBF", marker: "#257FAF", border: "#D5E7F1", shadow: "rgba(30,103,143,0.14)" },
  Forest: { name: "Forest", background: "#EFF6F1", card: "#F9FCFA", text: "#183126", subtleText: "#66806F", accent: "#2D8C63", marker: "#327A57", border: "#D5E4DA", shadow: "rgba(29,85,57,0.14)" },
  Sunset: { name: "Sunset", background: "#FFF3ED", card: "#FFFBF8", text: "#45221D", subtleText: "#8B675E", accent: "#FF8258", marker: "#F36E42", border: "#F7DDD2", shadow: "rgba(192,88,49,0.16)" },
  Lavender: { name: "Lavender", background: "#F6F0FB", card: "#FCFAFE", text: "#302343", subtleText: "#7C6D91", accent: "#9B7AF7", marker: "#8E66F5", border: "#E5D8F5", shadow: "rgba(124,89,199,0.14)" },
  Graphite: { name: "Graphite", background: "#F4F4F5", card: "#FFFFFF", text: "#1D1D20", subtleText: "#6E7077", accent: "#4C5D73", marker: "#465A71", border: "#E5E6EA", shadow: "rgba(35,42,56,0.12)" },
  Mint: { name: "Mint", background: "#ECFBF7", card: "#FAFEFD", text: "#13312B", subtleText: "#64877F", accent: "#25B89B", marker: "#1FA589", border: "#D3EEE6", shadow: "rgba(26,140,117,0.14)" },
  Rose: { name: "Rose", background: "#FFF0F4", card: "#FFF9FB", text: "#44212A", subtleText: "#916977", accent: "#E76D96", marker: "#D85A85", border: "#F3D8E1", shadow: "rgba(190,82,119,0.14)" },
  Sky: { name: "Sky", background: "#EEF6FF", card: "#FAFCFF", text: "#17324E", subtleText: "#67839D", accent: "#4A9FFF", marker: "#3C8DEA", border: "#D5E6F9", shadow: "rgba(62,127,207,0.14)" },
  Sand: { name: "Sand", background: "#FBF6EE", card: "#FFFCF8", text: "#453A2B", subtleText: "#8B7B67", accent: "#C79A5F", marker: "#B78951", border: "#EBDDCC", shadow: "rgba(162,123,74,0.14)" },
  Ember: { name: "Ember", background: "#FFF2EE", card: "#FFFBF9", text: "#49231C", subtleText: "#9A6A61", accent: "#E35D47", marker: "#D64C33", border: "#F3D6CF", shadow: "rgba(178,77,59,0.14)" },
  Ice: { name: "Ice", background: "#F1FBFE", card: "#FBFEFF", text: "#15313A", subtleText: "#67848B", accent: "#57B8D3", marker: "#3FA9C7", border: "#D5EEF4", shadow: "rgba(63,137,158,0.12)" },
  Cocoa: { name: "Cocoa", background: "#F7F0EC", card: "#FCFAF8", text: "#36241D", subtleText: "#81665B", accent: "#9B6B56", marker: "#8E5B43", border: "#E8D9D0", shadow: "rgba(118,86,71,0.14)" },
  Lime: { name: "Lime", background: "#F6FCEB", card: "#FDFFF8", text: "#243513", subtleText: "#76855F", accent: "#90C43E", marker: "#7BB130", border: "#E2EDCD", shadow: "rgba(102,143,40,0.14)" },
  Violet: { name: "Violet", background: "#F5F1FE", card: "#FCFBFF", text: "#2A2145", subtleText: "#776A9B", accent: "#7865F2", marker: "#6B56E5", border: "#E1D8F9", shadow: "rgba(96,79,188,0.14)" },
  Peach: { name: "Peach", background: "#FFF4EE", card: "#FFFDFB", text: "#4B2D23", subtleText: "#9A766A", accent: "#F39A77", marker: "#ED875F", border: "#F7DECW", shadow: "rgba(194,120,83,0.14)" },
  Slate: { name: "Slate", background: "#F2F5F8", card: "#FDFEFF", text: "#1D2B39", subtleText: "#6A7B8C", accent: "#5B7A99", marker: "#506E8C", border: "#DDE5ED", shadow: "rgba(60,84,109,0.14)" },
  Aurora: { name: "Aurora", background: "#EFFAF9", card: "#FBFEFE", text: "#183238", subtleText: "#66818A", accent: "#38B0A2", marker: "#2A9A8F", border: "#D4EDE9", shadow: "rgba(45,129,119,0.14)" },
  Mono: { name: "Mono", background: "#F2F2F2", card: "#FFFFFF", text: "#161616", subtleText: "#767676", accent: "#2C2C2C", marker: "#1E1E1E", border: "#E6E6E6", shadow: "rgba(28,28,28,0.12)" },
  Classic: { name: "Classic", background: "#F6F7FB", card: "#FFFFFF", text: "#1B2430", subtleText: "#6D7683", accent: "#4E7BFF", marker: "#5B8DEF", border: "#E5EAF2", shadow: "rgba(37,72,132,0.12)" }
};

export const themeNames = Object.keys(themes) as ThemeName[];

export function resolveTheme(name?: ThemeName | null) {
  if (!name) {
    return themes.Classic;
  }

  return themes[name] ?? themes.Classic;
}
