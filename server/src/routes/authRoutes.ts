import { Router } from "express";

import { login, loginSchema, register, registerSchema } from "../controllers/authController.js";
import { validate } from "../middleware/validate.js";

const router = Router();

router.post("/register", validate(registerSchema), register);
router.post("/login", validate(loginSchema), login);

export default router;
