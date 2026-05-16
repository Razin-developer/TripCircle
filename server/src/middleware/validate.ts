import type { NextFunction, Request, Response } from "express";
import type { AnyZodObject, ZodEffects } from "zod";

type Schema = AnyZodObject | ZodEffects<AnyZodObject>;

export function validate(schema: Schema) {
  return async (request: Request, _response: Response, next: NextFunction) => {
    const parsed = await schema.parseAsync({
      body: request.body,
      params: request.params,
      query: request.query
    });

    request.body = parsed.body;
    request.params = parsed.params;
    request.query = parsed.query;

    next();
  };
}
