import cors from "cors";
import express from "express";
import morgan from "morgan";

import authRoutes from "./routes/authRoutes.js";
import { connectDatabase } from "./config/db.js";
import groupRoutes from "./routes/groupRoutes.js";
import invitationRoutes from "./routes/invitationRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import { env } from "./config/env.js";
import { asyncHandler } from "./utils/asyncHandler.js";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler.js";

export function createApp() {
  const app = express();

  app.use(
    cors({
      origin: env.CLIENT_ORIGIN === "*" ? true : env.CLIENT_ORIGIN.split(","),
      credentials: true
    })
  );
  app.use(express.json({ limit: "2mb" }));
  app.use(morgan("dev"));

  app.get("/", (_request, response) => {
    response.json({
      ok: true,
      app: "TripCircle API",
      mode: process.env.VERCEL ? "vercel-serverless" : "node-server"
    });
  });

  app.get("/health", (_request, response) => {
    response.json({ ok: true, app: "TripCircle API" });
  });

  // In serverless environments we need to connect lazily per invocation.
  app.use(
    asyncHandler(async (_request, _response, next) => {
      await connectDatabase();
      next();
    })
  );

  app.use("/api/auth", authRoutes);
  app.use("/api/users", userRoutes);
  app.use("/api/groups", groupRoutes);
  app.use("/api/invitations", invitationRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
