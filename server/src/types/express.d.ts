import type { UserDocument } from "../models/User.js";

declare global {
  namespace Express {
    interface Request {
      user: UserDocument;
      validated?: {
        body?: unknown;
        params?: unknown;
        query?: unknown;
      };
    }
  }
}

export {};
