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

export function createSocketServer(server: HttpServer) {
  const io = new Server(server, {
    cors: {
      origin: env.CLIENT_ORIGIN === "*" ? true : env.CLIENT_ORIGIN.split(",")
    }
  });

  setSocketServer(io);

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace("Bearer ", "");

      if (!token) {
        return next(new Error("Missing token"));
      }

      const payload = verifyJwt(token);
      const user = await User.findById(payload.userId);

      if (!user) {
        return next(new Error("User not found"));
      }

      socket.data.user = user;
      return next();
    } catch {
      return next(new Error("Unauthorized"));
    }
  });

  io.on("connection", async (socket) => {
    const user = socket.data.user;
    const userId = user._id.toString();

    socket.join(`user:${userId}`);

    const groups = await setUserOnlineStatus(userId, true);
    groups.forEach((group) => {
      emitToGroup(group._id.toString(), "member:online", {
        groupId: group._id.toString(),
        userId
      });
    });

    socket.on("join:user", () => {
      socket.join(`user:${userId}`);
    });

    socket.on("join:group", async ({ groupId }: { groupId: string }) => {
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
        return;
      }

      socket.join(`group:${groupId}`);
    });

    socket.on("leave:group", ({ groupId }: { groupId: string }) => {
      socket.leave(`group:${groupId}`);
    });

    socket.on("location:update", async (payload: LocationPayload) => {
      const group = await Group.findById(payload.groupId);

      if (!group) {
        return;
      }

      const member = group.members.find(
        (item) => item.userId?.toString() === userId && item.status === "accepted"
      );

      if (!member?.isSharingLocation) {
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

      io.to(`group:${payload.groupId}`).emit("location:updated", {
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
      });
    });

    socket.on("disconnect", async () => {
      const disconnectedGroups = await setUserOnlineStatus(userId, false);
      disconnectedGroups.forEach((group) => {
        emitToGroup(group._id.toString(), "member:offline", {
          groupId: group._id.toString(),
          userId
        });
      });
    });
  });

  return io;
}
