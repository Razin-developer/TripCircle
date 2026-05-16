import { Router } from "express";

import { acceptInvitation, declineInvitation, getInvitations, invitationActionSchema } from "../controllers/invitationController.js";
import { authMiddleware } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";

const router = Router();

router.use(authMiddleware);
router.get("/", getInvitations);
router.post("/:invitationId/accept", validate(invitationActionSchema), acceptInvitation);
router.post("/:invitationId/decline", validate(invitationActionSchema), declineInvitation);

export default router;
