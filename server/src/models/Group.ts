import { Schema, model, type InferSchemaType, Types } from "mongoose";

const groupMemberSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      default: null
    },
    phoneNumber: {
      type: String,
      required: true
    },
    role: {
      type: String,
      enum: ["host", "member"],
      required: true
    },
    status: {
      type: String,
      enum: ["accepted", "pending", "declined"],
      default: "pending"
    },
    joinedAt: {
      type: Date,
      default: null
    },
    lastSeenAt: {
      type: Date,
      default: null
    },
    isOnline: {
      type: Boolean,
      default: false
    },
    isSharingLocation: {
      type: Boolean,
      default: false
    },
    locationUpdateMode: {
      type: String,
      enum: ["battery_saver", "balanced", "live"],
      default: "balanced"
    }
  },
  {
    _id: false
  }
);

const groupSchema = new Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true
    },
    hostUserId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },
    inviteCode: {
      type: String,
      required: true,
      index: true
    },
    members: {
      type: [groupMemberSchema],
      default: []
    }
  },
  {
    timestamps: true
  }
);

groupSchema.index({ "members.userId": 1 });
groupSchema.index({ "members.phoneNumber": 1 });

export type GroupMemberDocument = InferSchemaType<typeof groupMemberSchema> & {
  userId: Types.ObjectId | null;
};
export type GroupDocument = InferSchemaType<typeof groupSchema> & { _id: string };

export const Group = model("Group", groupSchema);
