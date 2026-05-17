import { api } from "@/services/api";
import type { SessionResponse, User } from "@/types";

export const authService = {
  async login(phoneNumber: string) {
    const { data } = await api.post<SessionResponse>("/auth/login", { phoneNumber });
    return data;
  },
  async register(payload: { phoneNumber: string; name: string; username: string }) {
    const { data } = await api.post<SessionResponse>("/auth/register", payload);
    return data;
  },
  async getMe() {
    const { data } = await api.get<{ user: User }>("/users/me");
    return data.user;
  },
  async updateProfile(payload: Partial<Pick<User, "name" | "phoneNumber" | "username" | "activeTheme">>) {
    const { data } = await api.patch<{ user: User }>("/users/me", payload);
    return data.user;
  },
  async updateTheme(activeTheme: string) {
    const { data } = await api.patch<{ user: User }>("/users/me/theme", { activeTheme });
    return data.user;
  },
  async updateUsername(username: string) {
    const { data } = await api.patch<{ user: User }>("/users/me/username", { username });
    return data.user;
  }
};
