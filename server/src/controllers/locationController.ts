import { z } from "zod";

import { Location } from "../models/Location.js";
import { emitToGroup } from "../services/socketService.js";
import { getGroupForAcceptedMember } from "../services/groupService.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { HttpError } from "../utils/httpError.js";

export const locationSchema = z.object({
  body: z.object({
    latitude: z.number(),
    longitude: z.number(),
    accuracy: z.number().nullable().optional(),
    speed: z.number().nullable().optional(),
    heading: z.number().nullable().optional(),
    batteryLevel: z.number().nullable().optional(),
    nearbyPlaceName: z.string().optional(),
    state: z.string().optional(),
    country: z.string().optional()
  }),
  params: z.object({
    groupId: z.string().min(1)
  }),
  query: z.object({}).default({})
});

export const postLocation = asyncHandler(async (request, response) => {
  const { group, member } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());

  if (!member.isSharingLocation) {
    throw new HttpError(403, "Location sharing is disabled for this group");
  }

  const location = await Location.findOneAndUpdate(
    {
      groupId: group._id,
      userId: request.user._id
    },
    {
      $set: {
        groupId: group._id,
        userId: request.user._id,
        phoneNumber: request.user.phoneNumber,
        deviceName: request.user.deviceName,
        ...request.body
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

  const payload = {
    groupId: group._id.toString(),
    userId: request.user._id.toString(),
    phoneNumber: request.user.phoneNumber,
    deviceName: request.user.deviceName,
    ...request.body,
    updatedAt: location.updatedAt
  };

  emitToGroup(group._id.toString(), "location:updated", payload);
  response.status(201).json({ location });
});
