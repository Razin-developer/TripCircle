import { Schema, model, type InferSchemaType } from "mongoose";

const locationSchema = new Schema(
  {
    groupId: {
      type: Schema.Types.ObjectId,
      ref: "Group",
      required: true,
      index: true
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },
    phoneNumber: {
      type: String,
      required: true
    },
    deviceName: {
      type: String,
      required: true
    },
    latitude: {
      type: Number,
      required: true
    },
    longitude: {
      type: Number,
      required: true
    },
    accuracy: {
      type: Number,
      default: null
    },
    speed: {
      type: Number,
      default: null
    },
    heading: {
      type: Number,
      default: null
    },
    batteryLevel: {
      type: Number,
      default: null
    },
    nearbyPlaceName: {
      type: String,
      default: ""
    },
    state: {
      type: String,
      default: ""
    },
    country: {
      type: String,
      default: ""
    }
  },
  {
    timestamps: false
  }
);

locationSchema.index({ groupId: 1, userId: 1 }, { unique: true });
locationSchema.index({ updatedAt: -1 });

locationSchema.set("timestamps", { createdAt: false, updatedAt: true });

export type LocationDocument = InferSchemaType<typeof locationSchema> & { _id: string };

export const Location = model("Location", locationSchema);
