import { create } from "zustand";

type Toast = {
  id: number;
  message: string;
};

type ToastState = {
  toasts: Toast[];
  showToast: (message: string) => void;
  dismissToast: (id: number) => void;
};

export const useToastStore = create<ToastState>((set, get) => ({
  toasts: [],
  showToast: (message) => {
    const toast = { id: Date.now(), message };
    set({ toasts: [...get().toasts, toast] });

    setTimeout(() => {
      get().dismissToast(toast.id);
    }, 2800);
  },
  dismissToast: (id) => {
    set({ toasts: get().toasts.filter((toast) => toast.id !== id) });
  }
}));
