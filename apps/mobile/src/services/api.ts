import axios from "axios";

import { API_BASE_URL } from "@/config";
import { useAuthStore } from "@/stores/authStore";

export const api = axios.create({
  baseURL: `${API_BASE_URL}/api`,
  timeout: 15000
});

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;

  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
});
