import { createServer } from "node:http";

import { createApp } from "./app.js";
import { connectDatabase } from "./config/db.js";
import { env } from "./config/env.js";
import { createSocketServer } from "./sockets/index.js";

async function bootstrap() {
  await connectDatabase();

  const app = createApp();
  const server = createServer(app);
  createSocketServer(server);

  server.listen(env.PORT, () => {
    console.log(`TripCircle API listening on http://localhost:${env.PORT}`);
  });
}

bootstrap().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
