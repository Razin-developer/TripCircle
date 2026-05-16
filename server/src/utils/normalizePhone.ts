export function normalizePhoneNumber(phoneNumber: string) {
  const cleaned = phoneNumber.replace(/[^\d+]/g, "");

  if (cleaned.startsWith("+")) {
    return cleaned;
  }

  return `+${cleaned}`;
}
