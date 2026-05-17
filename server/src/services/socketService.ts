import type { Server } from "socket.io";

let ioInstance: Server | null = null;

export function setSocketServer(io: Server) {
  ioInstance = io;
}

export function getSocketServer() {
  return ioInstance;
}

export function emitToUser(userId: string, event: string, payload: unknown) {
  getSocketServer()?.to(`user:${userId}`).emit(event, payload);
}

export function emitToGroup(groupId: string, event: string, payload: unknown) {
  getSocketServer()?.to(`group:${groupId}`).emit(event, payload);
}
