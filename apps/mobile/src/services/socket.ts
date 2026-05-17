import { io, type Socket } from "socket.io-client";

import { SOCKET_URL } from "@/config";
import { logger } from "@/services/logger";

type EventHandler = (payload: any) => void;

class SocketService {
  private socket: Socket | null = null;

  connect(token: string) {
    if (this.socket?.connected) {
      return this.socket;
    }

    void logger.log("info", "socket", "Socket connect requested", {
      url: SOCKET_URL
    });

    this.socket = io(SOCKET_URL, {
      transports: ["websocket"],
      auth: { token }
    });

    this.socket.on("connect", () => {
      void logger.log("info", "socket", "Socket connected", {
        id: this.socket?.id
      });
    });

    this.socket.on("disconnect", (reason) => {
      void logger.log("warn", "socket", "Socket disconnected", { reason });
    });

    this.socket.on("connect_error", (error) => {
      void logger.log("error", "socket", "Socket connect error", {
        message: error.message
      });
    });

    return this.socket;
  }

  disconnect() {
    void logger.log("info", "socket", "Socket disconnect requested");
    this.socket?.disconnect();
    this.socket = null;
  }

  get instance() {
    return this.socket;
  }

  on(event: string, callback: EventHandler) {
    this.socket?.on(event, callback);
  }

  off(event: string, callback?: EventHandler) {
    this.socket?.off(event, callback);
  }

  joinUser() {
    void logger.log("info", "socket", "Joining user room");
    this.socket?.emit("join:user");
  }

  joinGroup(groupId: string) {
    void logger.log("info", "socket", "Joining group room", { groupId });
    this.socket?.emit("join:group", { groupId });
  }

  leaveGroup(groupId: string) {
    void logger.log("info", "socket", "Leaving group room", { groupId });
    this.socket?.emit("leave:group", { groupId });
  }

  sendLocationUpdate(payload: Record<string, unknown>) {
    void logger.log("info", "socket", "Sending live location update", payload);
    this.socket?.emit("location:update", payload);
  }
}

export const socketService = new SocketService();
