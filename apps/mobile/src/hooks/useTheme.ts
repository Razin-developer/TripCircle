import { useMemo } from "react";

import { useAuthStore } from "@/stores/authStore";
import { resolveTheme } from "@/themes/themes";

export function useTheme() {
  const activeTheme = useAuthStore((state) => state.user?.activeTheme);

  return useMemo(() => resolveTheme(activeTheme), [activeTheme]);
}
