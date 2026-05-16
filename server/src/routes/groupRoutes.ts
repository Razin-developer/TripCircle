import { Router } from "express";

import { createInvitations, createInvitationSchema } from "../controllers/invitationController.js";
import { postLocation } from "../controllers/locationController.js";
import {
  createGroup,
  createGroupSchema,
  deleteGroup,
  getGroup,
  getGroups,
  getLatestLocations,
  getMembers,
  groupIdSchema,
  leaveGroup,
  stopSharing,
  updateGroup,
  updateGroupSchema
} from "../controllers/groupController.js";
import { locationSchema } from "../controllers/locationController.js";
import { authMiddleware } from "../middleware/auth.js";
import { validate } from "../middleware/validate.js";

const router = Router();

router.use(authMiddleware);
router.post("/", validate(createGroupSchema), createGroup);
router.get("/", getGroups);
router.get("/:groupId", validate(groupIdSchema), getGroup);
router.patch("/:groupId", validate(updateGroupSchema), updateGroup);
router.delete("/:groupId", validate(groupIdSchema), deleteGroup);
router.post("/:groupId/leave", validate(groupIdSchema), leaveGroup);
router.post("/:groupId/stop-sharing", validate(groupIdSchema), stopSharing);
router.post("/:groupId/invitations", validate(createInvitationSchema), createInvitations);
router.post("/:groupId/location", validate(locationSchema), postLocation);
router.get("/:groupId/locations/latest", validate(groupIdSchema), getLatestLocations);
router.get("/:groupId/members", validate(groupIdSchema), getMembers);

export default router;
