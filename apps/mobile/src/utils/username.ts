export const USERNAME_PATTERN = /^[a-z0-9._]{3,20}$/;
export const USERNAME_HELPER_TEXT = "Use 3-20 lowercase letters, numbers, dots, or underscores.";

export function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

export function isValidUsername(value: string) {
  return USERNAME_PATTERN.test(normalizeUsername(value));
}
