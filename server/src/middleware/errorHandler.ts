import type { NextFunction, Request, Response } from "express";
import mongoose from "mongoose";
import { ZodError } from "zod";

import { HttpError } from "../utils/httpError.js";

export function notFoundHandler(_request: Request, response: Response) {
  response.status(404).json({ message: "Route not found" });
}

export function errorHandler(error: Error, _request: Request, response: Response, _next: NextFunction) {
  if (error instanceof ZodError) {
    return response.status(400).json({
      message: "Validation failed",
      issues: error.flatten()
    });
  }

  if (error instanceof HttpError) {
    return response.status(error.statusCode).json({ message: error.message });
  }

  if (error instanceof mongoose.Error.ValidationError) {
    return response.status(400).json({ message: error.message });
  }

  if (
    error instanceof mongoose.mongo.MongoServerError &&
    error.code === 11000
  ) {
    const duplicateField = Object.keys(error.keyPattern ?? {})[0] ?? "value";
    return response.status(409).json({
      message: `${duplicateField} already exists`
    });
  }

  console.error(error);
  return response.status(500).json({ message: "Something went wrong" });
}
