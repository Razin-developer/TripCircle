import jwt from "jsonwebtoken";

import { env } from "../config/env.js";

export function signJwt(userId: string) {
  return jwt.sign({ userId }, env.JWT_SECRET, { expiresIn: "30d" });
}

export function verifyJwt(token: string) {
  return jwt.verify(token, env.JWT_SECRET) as { userId: string };
}
