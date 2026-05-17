import axios from "axios";

import { API_BASE_URL } from "@/config";
import { logger } from "@/services/logger";
import { useAuthStore } from "@/stores/authStore";

export const api = axios.create({
  baseURL: `${API_BASE_URL}/api`,
  timeout: 1000 * 60
});

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  const nextConfig = config;
  (nextConfig as typeof nextConfig & { metadata?: { startedAt: number } }).metadata = {
    startedAt: Date.now()
  };

  if (token) {
    nextConfig.headers.Authorization = `Bearer ${token}`;
  }

  void logger.log("info", "api", "API request started", {
    method: nextConfig.method?.toUpperCase(),
    baseURL: nextConfig.baseURL,
    url: nextConfig.url,
    params: nextConfig.params,
    data: nextConfig.data,
    headers: nextConfig.headers
  });

  return nextConfig;
});

api.interceptors.response.use(
  (response) => {
    const startedAt = (response.config as typeof response.config & { metadata?: { startedAt: number } }).metadata?.startedAt;

    void logger.log("info", "api", "API request completed", {
      method: response.config.method?.toUpperCase(),
      url: response.config.url,
      status: response.status,
      durationMs: startedAt ? Date.now() - startedAt : null,
      data: response.data
    });

    return response;
  },
  (error) => {
    const startedAt = (error.config as typeof error.config & { metadata?: { startedAt: number } })?.metadata?.startedAt;

    void logger.log("error", "api", "API request failed", {
      method: error.config?.method?.toUpperCase(),
      url: error.config?.url,
      status: error.response?.status ?? null,
      durationMs: startedAt ? Date.now() - startedAt : null,
      responseData: error.response?.data ?? null,
      message: error.message
    });

    return Promise.reject(error);
  }
);
