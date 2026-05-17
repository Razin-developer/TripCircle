import { Schema, model, type HydratedDocument, type InferSchemaType } from "mongoose";

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
    username: {
      type: String,
      required: true,
      unique: true,
      index: true,
      lowercase: true,
      trim: true
    },
    deviceName: {
      type: String,
      required: false,
      trim: true,
      default: null
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

userSchema.index({ username: 1 }, { unique: true });

export type UserDocument = HydratedDocument<InferSchemaType<typeof userSchema>>;

export const User = model("User", userSchema);
