import { api } from "@/services/api";
import type { Group, GroupDetailResponse, GroupMember, LocationSnapshot, LocationUpdateMode } from "@/types";

export const groupService = {
  async getGroups() {
    const { data } = await api.get<{ groups: Group[] }>("/groups");
    return data.groups;
  },
  async createGroup(name: string) {
    const { data } = await api.post<{ group: Group }>("/groups", { name });
    return data.group;
  },
  async getGroup(groupId: string) {
    const { data } = await api.get<GroupDetailResponse>(`/groups/${groupId}`);
    return data;
  },
  async updateGroup(
    groupId: string,
    payload: { name?: string; locationUpdateMode?: LocationUpdateMode; isSharingLocation?: boolean }
  ) {
    const { data } = await api.patch<{ group: Group }>(`/groups/${groupId}`, payload);
    return data.group;
  },
  async deleteGroup(groupId: string) {
    await api.delete(`/groups/${groupId}`);
  },
  async leaveGroup(groupId: string) {
    await api.post(`/groups/${groupId}/leave`);
  },
  async stopSharing(groupId: string) {
    const { data } = await api.post<{ group: Group }>(`/groups/${groupId}/stop-sharing`);
    return data.group;
  },
  async inviteContacts(groupId: string, contacts: Array<{ phoneNumber: string; name?: string }>) {
    const { data } = await api.post(`/groups/${groupId}/invitations`, { contacts });
    return data;
  },
  async postLocation(groupId: string, payload: Record<string, unknown>) {
    const { data } = await api.post(`/groups/${groupId}/location`, payload);
    return data;
  },
  async getLatestLocations(groupId: string) {
    const { data } = await api.get<{ locations: LocationSnapshot[] }>(`/groups/${groupId}/locations/latest`);
    return data.locations;
  },
  async getMembers(groupId: string) {
    const { data } = await api.get<{ members: GroupMember[] }>(`/groups/${groupId}/members`);
    return data.members;
  }
};
