import { Router } from "express";

import { getMe, updateDeviceName, updateDeviceSchema, updateMe, updateTheme, updateThemeSchema, updateUserSchema } from "../controllers/userController.js";
import { authMiddleware } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";

const router = Router();

router.use(authMiddleware);
router.get("/me", getMe);
router.patch("/me", validate(updateUserSchema), updateMe);
router.patch("/me/theme", validate(updateThemeSchema), updateTheme);
router.patch("/me/device-name", validate(updateDeviceSchema), updateDeviceName);

export default router;
