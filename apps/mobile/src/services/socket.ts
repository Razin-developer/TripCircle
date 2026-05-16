import { io, type Socket } from "socket.io-client";

import { SOCKET_URL } from "@/config";

type EventHandler = (payload: any) => void;

class SocketService {
  private socket: Socket | null = null;

  connect(token: string) {
    if (this.socket?.connected) {
      return this.socket;
    }

    this.socket = io(SOCKET_URL, {
      transports: ["websocket"],
      auth: { token }
    });

    return this.socket;
  }

  disconnect() {
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
    this.socket?.emit("join:user");
  }

  joinGroup(groupId: string) {
    this.socket?.emit("join:group", { groupId });
  }

  leaveGroup(groupId: string) {
    this.socket?.emit("leave:group", { groupId });
  }

  sendLocationUpdate(payload: Record<string, unknown>) {
    this.socket?.emit("location:update", payload);
  }
}

export const socketService = new SocketService();
