import { create } from "zustand";

import type { Invitation } from "@/types";

type InvitationState = {
  invitations: Invitation[];
  pendingCount: number;
  setInvitations: (invitations: Invitation[]) => void;
  upsertInvitation: (invitation: Invitation) => void;
};

export const useInvitationStore = create<InvitationState>((set, get) => ({
  invitations: [],
  pendingCount: 0,
  setInvitations: (invitations) =>
    set({
      invitations,
      pendingCount: invitations.filter((item) => item.status === "pending").length
    }),
  upsertInvitation: (invitation) => {
    const invitations = [...get().invitations];
    const index = invitations.findIndex((item) => item._id === invitation._id);

    if (index >= 0) {
      invitations[index] = invitation;
    } else {
      invitations.unshift(invitation);
    }

    set({
      invitations,
      pendingCount: invitations.filter((item) => item.status === "pending").length
    });
  }
}));
