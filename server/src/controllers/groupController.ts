import { z } from "zod";

import { Group } from "../models/Group.js";
import { Invitation } from "../models/Invitation.js";
import { Location } from "../models/Location.js";
import { getGroupForAcceptedMember, getGroupForAnyMember, getGroupMembersWithLocations, serializeGroupOverview } from "../services/groupService.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { generateInviteCode } from "../utils/inviteCode.js";
import { HttpError } from "../utils/httpError.js";

export const createGroupSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(80)
  }),
  params: z.object({}).default({}),
  query: z.object({}).default({})
});

export const groupIdSchema = z.object({
  body: z.object({}).default({}),
  params: z.object({
    groupId: z.string().min(1)
  }),
  query: z.object({}).default({})
});

export const updateGroupSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(80).optional(),
    locationUpdateMode: z.enum(["battery_saver", "balanced", "live"]).optional(),
    isSharingLocation: z.boolean().optional()
  }),
  params: z.object({
    groupId: z.string().min(1)
  }),
  query: z.object({}).default({})
});

export const createGroup = asyncHandler(async (request, response) => {
  const group = await Group.create({
    name: request.body.name,
    hostUserId: request.user._id,
    inviteCode: generateInviteCode(),
    members: [
      {
        userId: request.user._id,
        phoneNumber: request.user.phoneNumber,
        role: "host",
        status: "accepted",
        joinedAt: new Date(),
        lastSeenAt: new Date(),
        isOnline: false,
        isSharingLocation: false,
        locationUpdateMode: "balanced"
      }
    ]
  });

  response.status(201).json({
    group: await serializeGroupOverview(group)
  });
});

export const getGroups = asyncHandler(async (request, response) => {
  const groups = await Group.find({
    members: {
      $elemMatch: {
        userId: request.user._id,
        status: "accepted"
      }
    }
  }).sort({ updatedAt: -1 });

  response.json({
    groups: await Promise.all(groups.map((group) => serializeGroupOverview(group)))
  });
});

export const getGroup = asyncHandler(async (request, response) => {
  const { group } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());

  response.json({
    group: await serializeGroupOverview(group),
    members: await getGroupMembersWithLocations(group._id.toString())
  });
});

export const updateGroup = asyncHandler(async (request, response) => {
  const { group, member } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());
  const { name, locationUpdateMode, isSharingLocation } = request.body as z.infer<typeof updateGroupSchema>["body"];
  const isHost = group.hostUserId.toString() === request.user._id.toString();

  if (name) {
    if (!isHost) {
      throw new HttpError(403, "Only the host can rename this group");
    }

    group.name = name;
  }

  if (locationUpdateMode) {
    member.locationUpdateMode = locationUpdateMode;
  }

  if (typeof isSharingLocation === "boolean") {
    member.isSharingLocation = isSharingLocation;
  }

  await group.save();

  response.json({
    group: await serializeGroupOverview(group)
  });
});

export const deleteGroup = asyncHandler(async (request, response) => {
  const { group } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());

  if (group.hostUserId.toString() !== request.user._id.toString()) {
    throw new HttpError(403, "Only the host can delete this group");
  }

  await Promise.all([
    Group.findByIdAndDelete(group._id),
    Invitation.deleteMany({ groupId: group._id }),
    Location.deleteMany({ groupId: group._id })
  ]);

  response.json({ message: "Group deleted" });
});

export const leaveGroup = asyncHandler(async (request, response) => {
  const { group, member } = await getGroupForAnyMember(request.params.groupId, request.user._id.toString());

  if (member.role === "host") {
    throw new HttpError(400, "Hosts must delete the group instead of leaving it");
  }

  group.members = group.members.filter((item) => item.phoneNumber !== member.phoneNumber);
  await Promise.all([
    group.save(),
    Invitation.deleteMany({ groupId: group._id, invitedPhoneNumber: member.phoneNumber }),
    Location.deleteMany({ groupId: group._id, userId: request.user._id })
  ]);

  response.json({ message: "You left the group" });
});

export const stopSharing = asyncHandler(async (request, response) => {
  const { group, member } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());

  member.isSharingLocation = false;
  await group.save();

  response.json({
    message: "Location sharing stopped",
    group: await serializeGroupOverview(group)
  });
});

export const getLatestLocations = asyncHandler(async (request, response) => {
  const { group } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());
  const acceptedUserIds = group.members
    .filter((member) => member.status === "accepted" && member.userId)
    .map((member) => member.userId);
  const locations = await Location.find({
    groupId: group._id,
    userId: { $in: acceptedUserIds }
  }).sort({ updatedAt: -1 });

  response.json({ locations });
});

export const getMembers = asyncHandler(async (request, response) => {
  const { group } = await getGroupForAcceptedMember(request.params.groupId, request.user._id.toString());
  const isHost = group.hostUserId.toString() === request.user._id.toString();
  const members = await getGroupMembersWithLocations(group._id.toString());

  response.json({
    members: isHost ? members : members.filter((member) => member.status === "accepted")
  });
});
