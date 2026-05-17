# TripCircle

TripCircle is a private family and group travel tracking starter app built as a TypeScript monorepo with:

- `apps/mobile`: Expo React Native mobile app
- `server`: Node.js + Express + MongoDB + Socket.IO backend

The project is privacy-first:

- Location sharing only begins after a member accepts an invitation.
- Members see clear UI explaining when live sharing is active.
- Members can stop sharing or leave a group at any time.
- Background location is requested only for accepted groups that explicitly enable sharing.

## Project Structure

```text
TripCircle/
  apps/
    mobile/
      app/
      assets/
      src/
  server/
    src/
```

## Features Included

- Phone-number based onboarding with a mock OTP-style flow
- JWT-authenticated backend
- Group creation and inviting by contact phone numbers
- Pending invitation inbox with realtime updates
- Accepted member live map using `react-native-maps` and Socket.IO
- Group member list, host controls, and location mode settings
- Background location task using `expo-task-manager` + `expo-location`
- 20 app themes with a clean iOS-style visual direction
- Minimal logo concept at [logo-mark.svg](/C:/Users/razin/Desktop/Products/TripCircle/apps/mobile/assets/logo-mark.svg)

## 1. Install Dependencies

From the repo root:

```bash
npm install
```

If PowerShell gives you trouble with `npm.ps1`, run npm through Node directly:

```powershell
& "C:\Program Files\nodejs\node.exe" "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" install
```

## 2. Setup Environment Files

Server:

```bash
cp server/.env.example server/.env
```

Fill in:

- `PORT`
- `MONGODB_URI`
- `JWT_SECRET`
- `CLIENT_ORIGIN`

Mobile:

```bash
cp apps/mobile/.env.example apps/mobile/.env
```

Set these to your local machine IP when testing on physical phones:

- `EXPO_PUBLIC_API_BASE_URL=http://YOUR_COMPUTER_IP:4000`
- `EXPO_PUBLIC_SOCKET_URL=http://YOUR_COMPUTER_IP:4000`

Example:

```env
EXPO_PUBLIC_API_BASE_URL=http://192.168.1.20:4000
EXPO_PUBLIC_SOCKET_URL=http://192.168.1.20:4000
```

`localhost` works only for simulators and the same machine, not for another phone on Wi‑Fi.

## 3. Run MongoDB

Make sure MongoDB is running locally, for example:

```bash
mongod --dbpath /path/to/your/db
```

Or use MongoDB Community / MongoDB Atlas and point `MONGODB_URI` to that instance.

Default local connection used in `server/.env.example`:

```env
MONGODB_URI=mongodb://127.0.0.1:27017/tripcircle
```

## 4. Run the Server

From the repo root:

```bash
npm run dev:server
```

Health check:

```bash
http://localhost:4000/health
```

Main API groups:

- `/api/auth`
- `/api/users`
- `/api/groups`
- `/api/invitations`

## 4.1 Deploy the Server on Render

Render is a much better fit for this backend than Vercel because this app uses a long-running Node server and Socket.IO.

Important Render note:

- Render runs the build command you configure.
- If that command is only `npm run build`, then `tsc` runs before dependencies are installed.
- That is exactly what causes errors like `Cannot find module 'express'` and `Cannot find type definition file for 'node'`.

Recommended Render settings:

- Root Directory: `server`
- Build Command: `npm install && npm run build`
- Start Command: `npm run start`

This repo now includes [render.yaml](/C:/Users/razin/Desktop/Products/TripCircle/render.yaml) with those settings.

Required environment variables on Render:

- `MONGODB_URI`
- `JWT_SECRET`
- `CLIENT_ORIGIN`

You usually do not need to set `PORT` manually because Render provides it for web services.

## 5. Run the Expo App

From the repo root:

```bash
npm run dev:mobile
```

Then open:

- iOS Simulator
- Android Emulator
- Expo development build on a real device

Important: background location requires a development build or production build for iOS. Expo Go is not enough for full background tracking behavior.

## 6. Test With Multiple Phones

1. Start MongoDB.
2. Start the server.
3. Set `apps/mobile/.env` to your computer's LAN IP.
4. Create an Expo development build if you want to test background location properly.
5. Open the app on two phones or two simulator/device combinations.
6. Register different phone numbers.
7. On phone A, create a group and invite phone B using its number.
8. On phone B, accept the invitation in Inbox.
9. On phone B, enable location sharing from the permission screen.
10. Open the group map on both devices and confirm live marker updates.

## 7. How Location Permissions Work

TripCircle follows this flow:

1. User accepts an invitation.
2. App shows a dedicated explanation screen before tracking starts.
3. App requests foreground location permission.
4. App requests background location permission.
5. App starts background updates only for groups that the user explicitly enables.
6. User can stop sharing from Group Settings.
7. Leaving a group also stops background sharing for that group.

Location mode options:

- `Battery Saver`: 60s, 120m
- `Balanced`: 30s, 60m
- `Live`: 10s, 20m

The background task also avoids sending duplicate updates when the device has not moved enough.

## 8. Known Limitations

- The auth flow is intentionally simplified and uses a mock OTP-style experience instead of a real SMS provider.
- Push notifications are not fully wired yet; the realtime invitation flow currently depends on Socket.IO while the app is running.
- Reverse geocoding is done on the device, so some background updates may not resolve place names if the OS throttles network access.
- `react-native-maps` uses OpenStreetMap tiles here, but the base map behavior still depends on native map support on the device.
- Presence is socket-based, so a member may appear offline if the app is killed even if background location later resumes.
- The app icon concept is provided as SVG; for App Store / Play Store submission you should export final PNG assets and wire them into Expo config.

## Helpful Scripts

Root:

```bash
npm run dev:server
npm run dev:mobile
npm run typecheck
```

Server:

```bash
npm --workspace server run dev
npm --workspace server run build
```

Mobile:

```bash
npm --workspace @tripcircle/mobile run start
npm --workspace @tripcircle/mobile run ios
npm --workspace @tripcircle/mobile run android
```

## Notes For You As You Extend This

- The backend is organized by controllers, models, routes, and socket services so you can find logic by feature instead of hunting through one huge file.
- The mobile app keeps auth, invitation badge state, and toasts in small Zustand stores so screen components stay simpler.
- The background location task is in [backgroundLocationTask.ts](/C:/Users/razin/Desktop/Products/TripCircle/apps/mobile/src/tasks/backgroundLocationTask.ts), which is a good file to read slowly because it connects permissions, background execution, and API posting.
- Group realtime behavior is centered around [GroupMapScreen.tsx](/C:/Users/razin/Desktop/Products/TripCircle/apps/mobile/src/screens/group/GroupMapScreen.tsx) and [server/src/sockets/index.ts](/C:/Users/razin/Desktop/Products/TripCircle/server/src/sockets/index.ts).

## Useful Official References

These were helpful for the native setup choices in this starter:

- [Expo permissions guide](https://docs.expo.dev/guides/permissions)
- [Expo Location docs](https://docs.expo.dev/versions/v53.0.0/sdk/location/)
- [Expo TaskManager docs](https://docs.expo.dev/versions/latest/sdk/task-manager)
- [Expo Contacts docs](https://docs.expo.dev/versions/latest/sdk/contacts)
- [React Navigation getting started](https://reactnavigation.org/docs/getting-started)
