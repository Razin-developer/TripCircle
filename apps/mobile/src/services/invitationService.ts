import { api } from "@/services/api";
import type { Invitation } from "@/types";

export const invitationService = {
  async getInvitations() {
    const { data } = await api.get<{ invitations: Invitation[] }>("/invitations");
    return data.invitations;
  },
  async acceptInvitation(invitationId: string) {
    const { data } = await api.post<{ invitation: Invitation }>(`/invitations/${invitationId}/accept`);
    return data.invitation;
  },
  async declineInvitation(invitationId: string) {
    const { data } = await api.post<{ invitation: Invitation }>(`/invitations/${invitationId}/decline`);
    return data.invitation;
  }
};
