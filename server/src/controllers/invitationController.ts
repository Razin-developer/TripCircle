import { Types } from "mongoose";
import { z } from "zod";

import { Group } from "../models/Group.js";
import { Invitation } from "../models/Invitation.js";
import { User } from "../models/User.js";
import { emitToGroup, emitToUser } from "../services/socketService.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { HttpError } from "../utils/httpError.js";
import { normalizePhoneNumber } from "../utils/normalizePhone.js";

export const createInvitationSchema = z.object({
  body: z.object({
    contacts: z.array(
      z.object({
        name: z.string().trim().optional(),
        phoneNumber: z.string().min(6)
      })
    ).min(1)
  }),
  params: z.object({
    groupId: z.string().min(1)
  }),
  query: z.object({}).default({})
});

export const invitationActionSchema = z.object({
  body: z.object({}).default({}),
  params: z.object({
    invitationId: z.string().min(1)
  }),
  query: z.object({}).default({})
});

export const getInvitations = asyncHandler(async (request, response) => {
  const invitations = await Invitation.find({
    $or: [
      { invitedUserId: request.user._id },
      { invitedPhoneNumber: request.user.phoneNumber }
    ]
  }).sort({ createdAt: -1 });

  response.json({ invitations });
});

export const createInvitations = asyncHandler(async (request, response) => {
  const group = await Group.findById(request.params.groupId);

  if (!group) {
    throw new HttpError(404, "Group not found");
  }

  if (group.hostUserId.toString() !== request.user._id.toString()) {
    throw new HttpError(403, "Only the host can invite members");
  }

  const createdInvitations = [];

  for (const contact of request.body.contacts) {
    const phoneNumber = normalizePhoneNumber(contact.phoneNumber);
    const alreadyExists = group.members.some((member) => member.phoneNumber === phoneNumber);

    if (alreadyExists) {
      continue;
    }

    const invitedUser = await User.findOne({ phoneNumber });

    group.members.push({
      userId: invitedUser?._id ?? null,
      phoneNumber,
      role: "member",
      status: "pending",
      joinedAt: null,
      lastSeenAt: null,
      isOnline: false,
      isSharingLocation: false,
      locationUpdateMode: "balanced"
    });

    const invitation = await Invitation.create({
      groupId: group._id,
      groupName: group.name,
      hostUserId: request.user._id,
      hostName: request.user.name,
      invitedPhoneNumber: phoneNumber,
      invitedUserId: invitedUser?._id ?? null,
      status: "pending"
    });

    createdInvitations.push(invitation);

    if (invitedUser) {
      emitToUser(invitedUser._id.toString(), "invitation:new", { invitation });
    }
  }

  await group.save();
  emitToGroup(group._id.toString(), "group:membersUpdated", { groupId: group._id });

  response.status(201).json({ invitations: createdInvitations });
});

async function updateInvitationStatus(
  invitationId: string,
  user: { _id: string; phoneNumber: string },
  status: "accepted" | "declined"
) {
  const invitation = await Invitation.findById(invitationId);

  if (!invitation) {
    throw new HttpError(404, "Invitation not found");
  }

  const group = await Group.findById(invitation.groupId);

  if (!group) {
    throw new HttpError(404, "Group not found");
  }

  if (
    invitation.invitedUserId?.toString() !== user._id &&
    invitation.invitedPhoneNumber !== user.phoneNumber
  ) {
    throw new HttpError(403, "This invitation does not belong to you");
  }

  invitation.status = status;
  invitation.respondedAt = new Date();
  invitation.invitedUserId = invitation.invitedUserId ?? new Types.ObjectId(user._id);
  await invitation.save();

  const member = group.members.find((item) => item.phoneNumber === invitation.invitedPhoneNumber);

  if (!member) {
    throw new HttpError(404, "Group member slot not found");
  }

  member.status = status;
  member.userId = new Types.ObjectId(user._id);
  member.joinedAt = status === "accepted" ? new Date() : null;
  member.isSharingLocation = false;
  await group.save();

  const hostPayload = {
    invitationId: invitation._id,
    groupId: group._id,
    userId: user._id,
    invitedPhoneNumber: invitation.invitedPhoneNumber,
    status
  };

  emitToUser(invitation.hostUserId.toString(), "invitation:updated", { invitation });
  emitToUser(user._id, "invitation:updated", { invitation });
  emitToGroup(group._id.toString(), "group:membersUpdated", { groupId: group._id });

  if (status === "accepted") {
    emitToUser(invitation.hostUserId.toString(), "group:memberAccepted", hostPayload);
  } else {
    emitToUser(invitation.hostUserId.toString(), "group:memberDeclined", hostPayload);
  }

  return invitation;
}

export const acceptInvitation = asyncHandler(async (request, response) => {
  const invitation = await updateInvitationStatus(
    request.params.invitationId,
    {
      _id: request.user._id.toString(),
      phoneNumber: request.user.phoneNumber
    },
    "accepted"
  );
  response.json({ invitation });
});

export const declineInvitation = asyncHandler(async (request, response) => {
  const invitation = await updateInvitationStatus(
    request.params.invitationId,
    {
      _id: request.user._id.toString(),
      phoneNumber: request.user.phoneNumber
    },
    "declined"
  );
  response.json({ invitation });
});
