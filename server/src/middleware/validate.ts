import type { NextFunction, Request, Response } from "express";
import type { AnyZodObject, ZodEffects } from "zod";

type Schema = AnyZodObject | ZodEffects<AnyZodObject>;

export function validate(schema: Schema) {
  return async (request: Request, response: Response, next: NextFunction) => {
    try {
      const parsed = await schema.parseAsync({
        body: request.body,
        params: request.params,
        query: request.query,
      });

      request.validated = {
        body: parsed.body,
        params: parsed.params,
        query: parsed.query,
      };

      next();
    } catch (error: any) {
      return response.status(400).json({
        success: false,
        message: "Validation failed",
        errors: error.errors ?? error.message,
      });
    }
  };
}
