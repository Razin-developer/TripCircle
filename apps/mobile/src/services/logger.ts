import { Platform } from "react-native";
import * as Sharing from "expo-sharing";
import * as FileSystem from "expo-file-system/legacy";

type LogLevel = "info" | "warn" | "error";

type LogEntry = {
  timestamp: string;
  level: LogLevel;
  category: string;
  route: string;
  message: string;
  data?: unknown;
};

const LOG_DIRECTORY_URI = `${FileSystem.documentDirectory}tripcircle-logs`;
const MAX_SERIALIZED_LENGTH = 5000;

function getDailyLogFileUri() {
  const dayStamp = new Date().toISOString().slice(0, 10);
  return `${LOG_DIRECTORY_URI}/tripcircle-${dayStamp}.log`;
}

function sanitizeValue(value: unknown): unknown {
  if (value === null || value === undefined) {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item));
  }

  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, entryValue]) => {
        const lowerKey = key.toLowerCase();

        if (
          lowerKey.includes("authorization") ||
          lowerKey.includes("token") ||
          lowerKey.includes("password")
        ) {
          return [key, "[redacted]"];
        }

        return [key, sanitizeValue(entryValue)];
      })
    );
  }

  if (typeof value === "string" && value.length > MAX_SERIALIZED_LENGTH) {
    return `${value.slice(0, MAX_SERIALIZED_LENGTH)}...[truncated]`;
  }

  return value;
}

class AppLogger {
  private queue: Promise<void> = Promise.resolve();
  private initialized = false;
  private currentRoute = "unknown";

  private async ensureDirectory() {
    if (this.initialized) {
      return;
    }

    const info = await FileSystem.getInfoAsync(LOG_DIRECTORY_URI);
    if (!info.exists) {
      await FileSystem.makeDirectoryAsync(LOG_DIRECTORY_URI, { intermediates: true });
    }

    this.initialized = true;
  }

  private enqueueWrite(entry: LogEntry) {
    const line = `${JSON.stringify(entry)}\n`;

    this.queue = this.queue
      .then(async () => {
        await this.ensureDirectory();
        await FileSystem.writeAsStringAsync(getDailyLogFileUri(), line, {
          encoding: FileSystem.EncodingType.UTF8,
          append: true
        } as any);
      })
      .catch((error) => {
        console.error("TripCircle logger failed to write", error);
      });

    return this.queue;
  }

  setRouteContext(routeName?: string | null, params?: unknown) {
    this.currentRoute = routeName ?? "unknown";
    void this.log("info", "navigation", "Route changed", {
      routeName,
      params
    });
  }

  getRouteContext() {
    return this.currentRoute;
  }

  async log(level: LogLevel, category: string, message: string, data?: unknown) {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      category,
      route: this.currentRoute,
      message,
      data: sanitizeValue(data)
    };

    console.log(`[TripCircle:${category}] ${message}`, entry.data ?? "");
    await this.enqueueWrite(entry);
  }

  async readLatestLog() {
    const latestLogUri = await this.getLatestLogUri();

    if (!latestLogUri) {
      return null;
    }

    return FileSystem.readAsStringAsync(latestLogUri, {
      encoding: FileSystem.EncodingType.UTF8
    });
  }

  async getLatestLogUri() {
    await this.ensureDirectory();

    const files = await FileSystem.readDirectoryAsync(LOG_DIRECTORY_URI);
    const logFiles = files.filter((fileName) => fileName.endsWith(".log")).sort();
    const latestFile = logFiles.at(-1);

    if (!latestFile) {
      return null;
    }

    return `${LOG_DIRECTORY_URI}/${latestFile}`;
  }

  async getLatestLogInfo() {
    const latestLogUri = await this.getLatestLogUri();

    if (!latestLogUri) {
      return null;
    }

    const fileInfo = await FileSystem.getInfoAsync(latestLogUri);

    return {
      uri: latestLogUri,
      size: fileInfo.exists ? fileInfo.size ?? 0 : 0
    };
  }

  async shareLatestLog() {
    const latestLogUri = await this.getLatestLogUri();

    if (!latestLogUri) {
      throw new Error("No log file exists yet.");
    }

    const canShare = await Sharing.isAvailableAsync();

    if (!canShare) {
      return latestLogUri;
    }

    await Sharing.shareAsync(latestLogUri, {
      dialogTitle: "Export TripCircle logs",
      mimeType: "text/plain",
      UTI: "public.plain-text"
    });

    return latestLogUri;
  }

  async clearLogs() {
    await this.ensureDirectory();
    const files = await FileSystem.readDirectoryAsync(LOG_DIRECTORY_URI);

    await Promise.all(
      files
        .filter((fileName) => fileName.endsWith(".log"))
        .map((fileName) => FileSystem.deleteAsync(`${LOG_DIRECTORY_URI}/${fileName}`, { idempotent: true }))
    );
  }

  getHumanReadableLocation() {
    return Platform.select({
      ios: "TripCircle stores logs in the app documents area. Use Export to save the file into the Files app.",
      android: "TripCircle stores logs in the app documents area. Use Export to send the file to Files or another file manager.",
      default: "TripCircle stores logs in the app documents area."
    });
  }
}

export const logger = new AppLogger();
