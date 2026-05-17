import type { Server as HttpServer } from "node:http";

import { Types } from "mongoose";
import { Server } from "socket.io";

import { env } from "../config/env.js";
import { Group } from "../models/Group.js";
import { Location } from "../models/Location.js";
import { User } from "../models/User.js";
import { emitToGroup, setSocketServer } from "../services/socketService.js";
import { setUserOnlineStatus } from "../services/groupService.js";
import { verifyJwt } from "../utils/jwt.js";

type LocationPayload = {
  groupId: string;
  latitude: number;
  longitude: number;
  accuracy?: number | null;
  speed?: number | null;
  heading?: number | null;
  nearbyPlaceName?: string;
  state?: string;
  country?: string;
  batteryLevel?: number | null;
};

function socketLog(message: string, data?: Record<string, unknown>) {
  console.log(
    `[SOCKET] ${new Date().toISOString()} ${message}`,
    data ? JSON.stringify(data, null, 2) : ""
  );
}

function socketError(message: string, error?: unknown, data?: Record<string, unknown>) {
  console.error(`[SOCKET ERROR] ${new Date().toISOString()} ${message}`, {
    error: error instanceof Error ? error.message : error,
    ...data
  });
}

export function createSocketServer(server: HttpServer) {
  const io = new Server(server, {
    cors: {
      origin: env.CLIENT_ORIGIN === "*" ? true : env.CLIENT_ORIGIN.split(",")
    }
  });

  setSocketServer(io);

  socketLog("Socket.IO server created", {
    clientOrigin: env.CLIENT_ORIGIN
  });

  io.use(async (socket, next) => {
    try {
      socketLog("Auth middleware started", {
        socketId: socket.id,
        hasAuthToken: Boolean(socket.handshake.auth.token),
        hasAuthorizationHeader: Boolean(socket.handshake.headers.authorization)
      });

      const token =
        socket.handshake.auth.token ||
        socket.handshake.headers.authorization?.replace("Bearer ", "");

      if (!token) {
        socketLog("Socket auth failed: missing token", {
          socketId: socket.id
        });

        return next(new Error("Missing token"));
      }

      const payload = verifyJwt(token);
      const user = await User.findById(payload.userId);

      if (!user) {
        socketLog("Socket auth failed: user not found", {
          socketId: socket.id,
          userId: payload.userId
        });

        return next(new Error("User not found"));
      }

      socket.data.user = user;

      socketLog("Socket auth success", {
        socketId: socket.id,
        userId: user._id.toString(),
        phoneNumber: user.phoneNumber,
        username: user.username
      });

      return next();
    } catch (error) {
      socketError("Socket auth failed: unauthorized", error, {
        socketId: socket.id
      });

      return next(new Error("Unauthorized"));
    }
  });

  io.on("connection", async (socket) => {
    try {
      const user = socket.data.user;
      const userId = user._id.toString();

      socketLog("Client connected", {
        socketId: socket.id,
        userId,
        phoneNumber: user.phoneNumber,
        username: user.username
      });

      socket.join(`user:${userId}`);

      socketLog("Joined user room", {
        socketId: socket.id,
        room: `user:${userId}`
      });

      const groups = await setUserOnlineStatus(userId, true);

      socketLog("User marked online", {
        socketId: socket.id,
        userId,
        groupsCount: groups.length,
        groupIds: groups.map((group) => group._id.toString())
      });

      groups.forEach((group) => {
        emitToGroup(group._id.toString(), "member:online", {
          groupId: group._id.toString(),
          userId
        });

        socketLog("Emitted member:online", {
          groupId: group._id.toString(),
          userId
        });
      });

      socket.on("join:user", () => {
        socket.join(`user:${userId}`);

        socketLog("Event join:user received", {
          socketId: socket.id,
          userId,
          room: `user:${userId}`
        });
      });

      socket.on("join:group", async ({ groupId }: { groupId: string }) => {
        try {
          socketLog("Event join:group received", {
            socketId: socket.id,
            userId,
            groupId
          });

          if (!Types.ObjectId.isValid(groupId)) {
            socketLog("join:group failed: invalid groupId", {
              socketId: socket.id,
              userId,
              groupId
            });

            return;
          }

          const group = await Group.findOne({
            _id: groupId,
            members: {
              $elemMatch: {
                userId: new Types.ObjectId(userId),
                status: "accepted"
              }
            }
          });

          if (!group) {
            socketLog("join:group failed: group not found or user not accepted", {
              socketId: socket.id,
              userId,
              groupId
            });

            return;
          }

          socket.join(`group:${groupId}`);

          socketLog("Joined group room successfully", {
            socketId: socket.id,
            userId,
            groupId,
            room: `group:${groupId}`
          });
        } catch (error) {
          socketError("join:group crashed", error, {
            socketId: socket.id,
            userId,
            groupId
          });
        }
      });

      socket.on("leave:group", ({ groupId }: { groupId: string }) => {
        socket.leave(`group:${groupId}`);

        socketLog("Event leave:group received", {
          socketId: socket.id,
          userId,
          groupId,
          room: `group:${groupId}`
        });
      });

      socket.on("location:update", async (payload: LocationPayload) => {
        try {
          socketLog("Event location:update received", {
            socketId: socket.id,
            userId,
            groupId: payload.groupId,
            latitude: payload.latitude,
            longitude: payload.longitude,
            accuracy: payload.accuracy,
            speed: payload.speed,
            heading: payload.heading,
            batteryLevel: payload.batteryLevel
          });

          if (!Types.ObjectId.isValid(payload.groupId)) {
            socketLog("location:update failed: invalid groupId", {
              socketId: socket.id,
              userId,
              groupId: payload.groupId
            });

            return;
          }

          const group = await Group.findById(payload.groupId);

          if (!group) {
            socketLog("location:update failed: group not found", {
              socketId: socket.id,
              userId,
              groupId: payload.groupId
            });

            return;
          }

          const member = group.members.find(
            (item) => item.userId?.toString() === userId && item.status === "accepted"
          );

          if (!member) {
            socketLog("location:update failed: user is not accepted member", {
              socketId: socket.id,
              userId,
              groupId: payload.groupId
            });

            return;
          }

          if (!member.isSharingLocation) {
            socketLog("location:update ignored: location sharing disabled", {
              socketId: socket.id,
              userId,
              groupId: payload.groupId
            });

            return;
          }

          const location = await Location.findOneAndUpdate(
            {
              groupId: group._id,
              userId: user._id
            },
            {
              $set: {
                groupId: group._id,
                userId: user._id,
                phoneNumber: user.phoneNumber,
                username: user.username,
                latitude: payload.latitude,
                longitude: payload.longitude,
                accuracy: payload.accuracy ?? null,
                speed: payload.speed ?? null,
                heading: payload.heading ?? null,
                nearbyPlaceName: payload.nearbyPlaceName ?? "",
                state: payload.state ?? "",
                country: payload.country ?? "",
                batteryLevel: payload.batteryLevel ?? null
              }
            },
            {
              new: true,
              upsert: true,
              setDefaultsOnInsert: true
            }
          );

          member.lastSeenAt = new Date();
          await group.save();

          const updatedAt = new Date().toISOString();

          const responsePayload = {
            groupId: payload.groupId,
            userId,
            phoneNumber: user.phoneNumber,
            username: user.username,
            latitude: payload.latitude,
            longitude: payload.longitude,
            accuracy: payload.accuracy ?? null,
            speed: payload.speed ?? null,
            heading: payload.heading ?? null,
            nearbyPlaceName: payload.nearbyPlaceName ?? "",
            state: payload.state ?? "",
            country: payload.country ?? "",
            batteryLevel: payload.batteryLevel ?? null,
            updatedAt
          };

          io.to(`group:${payload.groupId}`).emit("location:updated", responsePayload);

          socketLog("location:updated emitted successfully", {
            socketId: socket.id,
            userId,
            groupId: payload.groupId,
            locationId: location?._id?.toString(),
            room: `group:${payload.groupId}`,
            updatedAt
          });
        } catch (error) {
          socketError("location:update crashed", error, {
            socketId: socket.id,
            userId,
            groupId: payload?.groupId
          });
        }
      });

      socket.on("disconnect", async (reason) => {
        try {
          socketLog("Client disconnected", {
            socketId: socket.id,
            userId,
            reason
          });

          const disconnectedGroups = await setUserOnlineStatus(userId, false);

          socketLog("User marked offline", {
            socketId: socket.id,
            userId,
            groupsCount: disconnectedGroups.length,
            groupIds: disconnectedGroups.map((group) => group._id.toString())
          });

          disconnectedGroups.forEach((group) => {
            emitToGroup(group._id.toString(), "member:offline", {
              groupId: group._id.toString(),
              userId
            });

            socketLog("Emitted member:offline", {
              groupId: group._id.toString(),
              userId
            });
          });
        } catch (error) {
          socketError("disconnect handler crashed", error, {
            socketId: socket.id,
            userId
          });
        }
      });
    } catch (error) {
      socketError("connection handler crashed", error, {
        socketId: socket.id
      });

      socket.disconnect(true);
    }
  });

  return io;
}