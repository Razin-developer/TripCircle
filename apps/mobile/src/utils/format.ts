export function formatRelativeTime(value?: string | Date | null) {
  if (!value) {
    return "No updates yet";
  }

  const date = typeof value === "string" ? new Date(value) : value;
  const diffMs = Date.now() - date.getTime();
  const minutes = Math.max(1, Math.round(diffMs / 60000));

  if (minutes < 60) {
    return `${minutes}m ago`;
  }

  const hours = Math.round(minutes / 60);
  if (hours < 24) {
    return `${hours}h ago`;
  }

  const days = Math.round(hours / 24);
  return `${days}d ago`;
}

export function getInitials(name?: string | null, fallback = "TC") {
  if (!name?.trim()) {
    return fallback;
  }

  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

export function maskPhoneNumber(phoneNumber: string, showFull: boolean) {
  if (showFull) {
    return phoneNumber;
  }

  return `${phoneNumber.slice(0, 3)}••••${phoneNumber.slice(-2)}`;
}

export function formatCoordinate(value?: number | null) {
  if (typeof value !== "number") {
    return "Unknown";
  }

  return value.toFixed(5);
}
