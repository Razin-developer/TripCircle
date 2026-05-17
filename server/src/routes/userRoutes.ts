import { Router } from "express";

import {
  getMe,
  searchUsers,
  searchUsersSchema,
  updateMe,
  updateTheme,
  updateThemeSchema,
  updateUserSchema,
  updateUsername,
  updateUsernameSchema
} from "../controllers/userController.js";
import { authMiddleware } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";

const router = Router();

router.use(authMiddleware);
router.get("/search", validate(searchUsersSchema), searchUsers);
router.get("/me", getMe);
router.patch("/me", validate(updateUserSchema), updateMe);
router.patch("/me/theme", validate(updateThemeSchema), updateTheme);
router.patch("/me/username", validate(updateUsernameSchema), updateUsername);

export default router;
