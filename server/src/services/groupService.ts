import { Types } from "mongoose";

import { Group, type GroupDocument } from "../models/Group.js";
import { Location } from "../models/Location.js";
import { User } from "../models/User.js";
import { HttpError } from "../utils/httpError.js";

export async function getGroupForAcceptedMember(groupId: string, userId: string) {
  const group = await Group.findById(groupId);

  if (!group) {
    throw new HttpError(404, "Group not found");
  }

  const member = group.members.find(
    (item) => item.userId?.toString() === userId && item.status === "accepted"
  );

  if (!member) {
    throw new HttpError(403, "You do not have access to this group");
  }

  return { group, member };
}

export async function getGroupForAnyMember(groupId: string, userId: string) {
  const group = await Group.findById(groupId);

  if (!group) {
    throw new HttpError(404, "Group not found");
  }

  const member = group.members.find((item) => item.userId?.toString() === userId);

  if (!member) {
    throw new HttpError(403, "You do not belong to this group");
  }

  return { group, member };
}

export async function setUserOnlineStatus(userId: string, isOnline: boolean) {
  const groups = await Group.find({
    members: {
      $elemMatch: {
        userId: new Types.ObjectId(userId),
        status: "accepted"
      }
    }
  });

  await Promise.all(
    groups.map(async (group) => {
      const member = group.members.find(
        (item) => item.userId?.toString() === userId && item.status === "accepted"
      );

      if (!member) {
        return;
      }

      member.isOnline = isOnline;
      member.lastSeenAt = new Date();
      await group.save();
    })
  );

  return groups;
}

export async function serializeGroupOverview(group: GroupDocument) {
  const hostUser = await User.findById(group.hostUserId).lean();
  const memberUsers = await User.find({
    _id: {
      $in: group.members
        .map((member) => member.userId)
        .filter(Boolean)
    }
  }).lean();
  const userById = new Map(memberUsers.map((user) => [user._id.toString(), user]));
  const hostMember = group.members.find((member) => member.role === "host");
  const acceptedMembers = group.members.filter((member) => member.status === "accepted");
  const onlineMembers = acceptedMembers.filter((member) => member.isOnline);

  return {
    _id: group._id,
    name: group.name,
    hostUserId: group.hostUserId,
    inviteCode: group.inviteCode,
    hostName: hostUser?.name ?? "Host",
    hostPhoneNumber: hostMember?.phoneNumber ?? "",
    members: group.members.map((member) => ({
      ...member.toObject(),
      user: member.userId ? userById.get(member.userId.toString()) ?? null : null
    })),
    acceptedCount: acceptedMembers.length,
    onlineCount: onlineMembers.length,
    lastUpdated: group.updatedAt,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt
  };
}

export async function getGroupMembersWithLocations(groupId: string) {
  const locations = await Location.find({ groupId }).lean();
  const locationByUserId = new Map(locations.map((item) => [item.userId.toString(), item]));
  const group = await Group.findById(groupId).lean();

  if (!group) {
    throw new HttpError(404, "Group not found");
  }

  const users = await User.find({
    _id: {
      $in: group.members
        .map((member) => member.userId)
        .filter(Boolean)
    }
  }).lean();
  const userById = new Map(users.map((user) => [user._id.toString(), user]));

  return group.members.map((member) => ({
    ...member,
    user: member.userId ? userById.get(member.userId.toString()) ?? null : null,
    location: member.userId ? locationByUserId.get(member.userId.toString()) ?? null : null
  }));
}
