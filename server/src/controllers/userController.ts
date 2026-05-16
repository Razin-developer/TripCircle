import { z } from "zod";

import { asyncHandler } from "../utils/asyncHandler.js";
import { normalizePhoneNumber } from "../utils/normalizePhone.js";

export const updateUserSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(60).optional(),
    phoneNumber: z.string().min(6).optional(),
    deviceName: z.string().trim().min(2).max(60).optional(),
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

export const updateDeviceSchema = z.object({
  body: z.object({
    deviceName: z.string().trim().min(2).max(60)
  }),
  params: z.object({}).default({}),
  query: z.object({}).default({})
});

export const getMe = asyncHandler(async (request, response) => {
  response.json({ user: request.user });
});

export const updateMe = asyncHandler(async (request, response) => {
  const { name, phoneNumber, deviceName, activeTheme } = request.body as z.infer<typeof updateUserSchema>["body"];

  if (name) {
    request.user.name = name;
  }

  if (phoneNumber) {
    request.user.phoneNumber = normalizePhoneNumber(phoneNumber);
  }

  if (deviceName) {
    request.user.deviceName = deviceName;
  }

  if (activeTheme) {
    request.user.activeTheme = activeTheme;
  }

  await request.user.save();
  response.json({ user: request.user });
});

export const updateTheme = asyncHandler(async (request, response) => {
  request.user.activeTheme = request.body.activeTheme;
  await request.user.save();
  response.json({ user: request.user });
});

export const updateDeviceName = asyncHandler(async (request, response) => {
  request.user.deviceName = request.body.deviceName;
  await request.user.save();
  response.json({ user: request.user });
});
