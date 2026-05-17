import { z } from "zod";
import { Types } from "mongoose";

import { Group } from "../models/Group.js";
import { User } from "../models/User.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { HttpError } from "../utils/httpError.js";
import { normalizePhoneNumber } from "../utils/normalizePhone.js";
import { escapeRegex, normalizeUsername, rankUsernameMatch, usernameSchema } from "../utils/username.js";

export const updateUserSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(60).optional(),
    phoneNumber: z.string().min(6).optional(),
    username: usernameSchema.optional(),
    activeTheme: z.string().trim().min(2).max(40).optional()
  }),
  params: z.object({}).default({}),
  query: z.object({}).default({})
});

export const updateThemeSchema = z.object({
  body: z.object({
    activeTheme: z.string().trim().min(2).max(40)
  }),
  params: z.object({}).default({}),
  query: z.object({}).default({})
});

export const updateUsernameSchema = z.object({
  body: z.object({
    username: usernameSchema
  }),
  params: z.object({}).default({}),
  query: z.object({}).default({})
});

export const searchUsersSchema = z.object({
  body: z.object({}).default({}),
  params: z.object({}).default({}),
  query: z.object({
    q: z.string().trim().min(1),
    groupId: z.string().trim().min(1).optional()
  })
});

async function ensureUsernameAvailable(username: string, currentUserId: string) {
  const existingUser = await User.findOne({ username });

  if (existingUser && existingUser._id.toString() !== currentUserId) {
    throw new HttpError(409, "Username already exists");
  }
}

export const getMe = asyncHandler(async (request, response) => {
  response.json({ user: request.user });
});

export const updateMe = asyncHandler(async (request, response) => {
  const { body } = request.validated as z.infer<typeof updateUserSchema>;
  const { name, phoneNumber, username, activeTheme } = body;

  if (name) {
    request.user.name = name;
  }

  if (phoneNumber) {
    request.user.phoneNumber = normalizePhoneNumber(phoneNumber);
  }

  if (username) {
    const normalizedUsername = normalizeUsername(username);
    await ensureUsernameAvailable(normalizedUsername, request.user._id.toString());
    request.user.username = normalizedUsername;
    request.user.deviceName = normalizedUsername;
  }

  if (activeTheme) {
    request.user.activeTheme = activeTheme;
  }

  await request.user.save();
  response.json({ user: request.user });
});

export const updateTheme = asyncHandler(async (request, response) => {
  const { body } = request.validated as z.infer<typeof updateThemeSchema>;
  request.user.activeTheme = body.activeTheme;
  await request.user.save();
  response.json({ user: request.user });
});

export const updateUsername = asyncHandler(async (request, response) => {
  const { body } = request.validated as z.infer<typeof updateUsernameSchema>;
  const normalizedUsername = normalizeUsername(body.username);
  await ensureUsernameAvailable(normalizedUsername, request.user._id.toString());
  request.user.username = normalizedUsername;
  request.user.deviceName = normalizedUsername;
  await request.user.save();
  response.json({ user: request.user });
});

export const searchUsers = asyncHandler(async (request, response) => {
  const { query } = request.validated as z.infer<typeof searchUsersSchema>;
  const normalizedQuery = normalizeUsername(query.q);
  const usernameRegex = new RegExp(escapeRegex(normalizedQuery), "i");
  const excludedUserIds = new Set<string>([request.user._id.toString()]);

  if (query.groupId) {
    const group = await Group.findById(query.groupId).select("members.userId");

    if (group) {
      group.members.forEach((member) => {
        if (member.userId) {
          excludedUserIds.add(member.userId.toString());
        }
      });
    }
  }

  const users = await User.find({
    _id: {
      $nin: Array.from(excludedUserIds).map((id) => new Types.ObjectId(id))
    },
    username: usernameRegex
  })
    .select("_id name username avatarColor")
    .limit(20)
    .lean();

  const rankedUsers = users
    .sort((left, right) => {
      const scoreDifference =
        rankUsernameMatch(left.username, normalizedQuery) -
        rankUsernameMatch(right.username, normalizedQuery);

      if (scoreDifference !== 0) {
        return scoreDifference;
      }

      return left.username.localeCompare(right.username);
    })
    .slice(0, 5);

  response.json({ users: rankedUsers });
});
