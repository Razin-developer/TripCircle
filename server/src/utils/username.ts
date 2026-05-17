import { z } from "zod";

export const USERNAME_PATTERN = /^[a-z0-9._]{3,20}$/;
export const USERNAME_VALIDATION_MESSAGE =
  "Username must be 3-20 characters and use only lowercase letters, numbers, dots, or underscores.";

export const usernameSchema = z
  .string()
  .trim()
  .toLowerCase()
  .regex(USERNAME_PATTERN, USERNAME_VALIDATION_MESSAGE);

export function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

export function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function rankUsernameMatch(username: string, query: string) {
  const normalizedUsername = normalizeUsername(username);
  const normalizedQuery = normalizeUsername(query);

  if (normalizedUsername.startsWith(normalizedQuery)) {
    return 0;
  }

  const includesIndex = normalizedUsername.indexOf(normalizedQuery);

  if (includesIndex >= 0) {
    return 100 + includesIndex;
  }

  return 999;
}
