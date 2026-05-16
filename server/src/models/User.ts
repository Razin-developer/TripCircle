import { Schema, model, type InferSchemaType } from "mongoose";

const userSchema = new Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true
    },
    phoneNumber: {
      type: String,
      required: true,
      unique: true,
      index: true
    },
    deviceName: {
      type: String,
      required: true,
      trim: true
    },
    avatarColor: {
      type: String,
      required: true
    },
    activeTheme: {
      type: String,
      default: "Classic"
    }
  },
  {
    timestamps: true
  }
);

export type UserDocument = InferSchemaType<typeof userSchema> & { _id: string };

export const User = model("User", userSchema);
