import { Schema, model, type HydratedDocument, type InferSchemaType } from "mongoose";

const invitationSchema = new Schema(
  {
    groupId: {
      type: Schema.Types.ObjectId,
      ref: "Group",
      required: true,
      index: true
    },
    groupName: {
      type: String,
      required: true
    },
    hostUserId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },
    hostName: {
      type: String,
      required: true
    },
    invitedPhoneNumber: {
      type: String,
      required: true,
      index: true
    },
    invitedUserId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      default: null,
      index: true
    },
    status: {
      type: String,
      enum: ["pending", "accepted", "declined"],
      default: "pending"
    },
    respondedAt: {
      type: Date,
      default: null
    }
  },
  {
    timestamps: true
  }
);

invitationSchema.index({ invitedPhoneNumber: 1, status: 1 });
invitationSchema.index({ invitedUserId: 1, status: 1 });

export type InvitationDocument = HydratedDocument<InferSchemaType<typeof invitationSchema>>;

export const Invitation = model("Invitation", invitationSchema);
