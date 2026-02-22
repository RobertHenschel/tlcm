# ThinLinc Connection Manager (v2)

Native macOS app built with SwiftUI. Lets you add and manage ThinLinc connections with a simple, platform-native UI.

## Requirements

- macOS 13.0 or later
- **ThinLinc Client** must be installed (the app will not run without it). Download from [Cendio](https://www.cendio.com/thinlinc/download/). Standard locations: `/Applications/ThinLinc Client.app` or `~/Applications/ThinLinc Client.app`.
- **Xcode** (full app) to build — Command Line Tools alone are not enough

## Building (universal binary)

1. Select Xcode as the active developer directory (if you usually use Command Line Tools):
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

2. From the `v2` directory, run:
   ```bash
   ./build.sh
   ```
   Or open `ThinLincConnectionManager.xcodeproj` in Xcode and press **Product → Build** (⌘B).

3. The app is produced as a **universal binary** (runs on both Intel and Apple Silicon Macs):
   - **Path after build:** `build/Build/Products/Release/ThinLinc Connection Manager.app`

## Creating a DMG (for easy copy/share)

After building, run:
```bash
./create_dmg.sh
```
This creates **ThinLinc-Connection-Manager.dmg** in the `v2` directory. Recipients open the DMG and drag the app to Applications (or anywhere). One file to copy or send.

## Dropbox sync (same setup on all devices)

On startup the app checks for Dropbox (`~/Dropbox` or `~/Library/CloudStorage/Dropbox`). If found, it uses a **single file in the Dropbox root** for all connection data:

- **File:** `tlcm-connections.json` in the root of your Dropbox folder  
- **Effect:** Add or edit connections on one Mac; they appear on any other Mac (or device) that runs the app with the same Dropbox linked. No manual copy needed.
- The main window shows “Synced via Dropbox” under the title when this file is in use.
- If Dropbox is not installed, the app falls back to `~/Library/Application Support/ThinLincConnectionManager/connections.json` (local only).

## Running on another machine

- **Option A:** Copy **ThinLinc Connection Manager.app** to the other Mac (e.g. USB, AirDrop).
- **Option B:** Copy **ThinLinc-Connection-Manager.dmg**, open it there, then drag the app to Applications.
- No installer or Xcode required. If both machines use the same Dropbox, connections stay in sync via `tlcm-connections.json` in Dropbox root; otherwise each Mac uses its own local file.

## Launching a connection

- Click **Connect** on a row, or double-click the row, to start the ThinLinc client with that connection. A small config file is written to `~/Library/Application Support/ThinLincConnectionManager/` and the client is opened with it. If “Connect automatically” was set for the connection, the client is started with auto-connect.

## Project layout

- `ThinLincConnectionManager/` — Swift source
  - `ThinLincConnectionManagerApp.swift` — App entry; gates on ThinLinc client being installed
  - `ContentView.swift` — Main window (connection list, Connect button, double-click to launch)
  - `Models/Connection.swift` — Connection model (compatible with v1 JSON)
  - `Storage/ConnectionsStore.swift` — Load/save connections (Dropbox or Application Support)
  - `Storage/DropboxLocator.swift` — Detects Dropbox and path for `tlcm-connections.json`
  - `ThinLinc/ThinLincClientFinder.swift` — Detects ThinLinc Client.app at launch
  - `ThinLinc/ThinLincClientLauncher.swift` — Writes .conf and runs `open -a "ThinLinc Client" …`
  - `Views/AddConnectionSheet.swift` — “Add Connection” sheet (name, server, username, auth)
  - `Views/ThinLincNotFoundView.swift` — Shown when the client is not installed (with Quit)
  - `Assets.xcassets` — App icon and accent color

## Connection format

Same as v1: each connection has `name`, `server`, `username`, `auth_type`, `auth_data`, `auto_connect`. Stored in JSON; new entries get a UUID `id` when saved.
