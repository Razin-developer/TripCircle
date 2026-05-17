import { z } from "zod";
import { Types } from "mongoose";

import { Group } from "../models/Group.js";
import { Invitation } from "../models/Invitation.js";
import { User } from "../models/User.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { signJwt } from "../utils/jwt.js";
import { normalizePhoneNumber } from "../utils/normalizePhone.js";
import { HttpError } from "../utils/httpError.js";
import { normalizeUsername, usernameSchema } from "../utils/username.js";

const authSchema = z.object({
  body: z.object({
    phoneNumber: z.string().min(6),
    name: z.string().trim().min(2).max(60).optional(),
    username: usernameSchema.optional()
  }),
  params: z.object({}).default({}),
  query: z.object({}).default({})
});

function getAvatarColor(phoneNumber: string) {
  const palette = ["#5B8DEF", "#49B6A5", "#ED8B72", "#9C8CF3", "#E7B35C", "#64C4ED"];
  const seed = phoneNumber.split("").reduce((accumulator, character) => accumulator + character.charCodeAt(0), 0);
  return palette[seed % palette.length];
}

async function linkPendingInvitations(userId: string, phoneNumber: string) {
  await Invitation.updateMany(
    { invitedPhoneNumber: phoneNumber, invitedUserId: null },
    { $set: { invitedUserId: userId } }
  );
}

async function linkPendingGroupMembers(userId: string, phoneNumber: string) {
  await Group.updateMany(
    {
      members: {
        $elemMatch: {
          phoneNumber,
          userId: null
        }
      }
    },
    {
      $set: {
        "members.$[member].userId": new Types.ObjectId(userId)
      }
    },
    {
      arrayFilters: [
        {
          "member.phoneNumber": phoneNumber,
          "member.userId": null
        }
      ]
    }
  );
}

export const registerSchema = authSchema.refine(
  (value) => Boolean(value.body.name && value.body.username),
  "Name and username are required"
);

export const loginSchema = authSchema;

export const register = asyncHandler(async (request, response) => {
  const { body } = request.validated as z.infer<typeof registerSchema>;
  const { phoneNumber, name, username } = body;
  const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
  const normalizedUsername = normalizeUsername(username!);

  const existingUsernameOwner = await User.findOne({ username: normalizedUsername });

  if (existingUsernameOwner && existingUsernameOwner.phoneNumber !== normalizedPhoneNumber) {
    throw new HttpError(409, "Username already exists");
  }

  const user = await User.findOneAndUpdate(
    { phoneNumber: normalizedPhoneNumber },
    {
      $set: {
        name,
        username: normalizedUsername,
        deviceName: normalizedUsername,
        avatarColor: getAvatarColor(normalizedPhoneNumber)
      }
    },
    {
      new: true,
      upsert: true,
      setDefaultsOnInsert: true
    }
  );

  await linkPendingInvitations(user._id.toString(), normalizedPhoneNumber);
  await linkPendingGroupMembers(user._id.toString(), normalizedPhoneNumber);

  response.status(201).json({
    token: signJwt(user._id.toString()),
    user
  });
});

export const login = asyncHandler(async (request, response) => {
  const { body } = request.validated as z.infer<typeof loginSchema>;
  const { phoneNumber } = body;
  const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);

  const user = await User.findOne({ phoneNumber: normalizedPhoneNumber });

  if (!user) {
    throw new HttpError(404, "User not found. Please complete profile setup first.");
  }

  await linkPendingInvitations(user._id.toString(), normalizedPhoneNumber);
  await linkPendingGroupMembers(user._id.toString(), normalizedPhoneNumber);

  response.json({
    token: signJwt(user._id.toString()),
    user
  });
});
