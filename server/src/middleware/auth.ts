import type { NextFunction, Request, Response } from "express";

import { User } from "../models/User.js";
import { verifyJwt } from "../utils/jwt.js";
import { HttpError } from "../utils/httpError.js";

export async function authMiddleware(request: Request, _response: Response, next: NextFunction) {
  const authorization = request.headers.authorization;

  if (!authorization?.startsWith("Bearer ")) {
    return next(new HttpError(401, "Missing authentication token"));
  }

  const token = authorization.replace("Bearer ", "");

  try {
    const payload = verifyJwt(token);
    const user = await User.findById(payload.userId);

    if (!user) {
      return next(new HttpError(401, "User not found"));
    }

    request.user = user;
    return next();
  } catch {
    return next(new HttpError(401, "Invalid authentication token"));
  }
}
