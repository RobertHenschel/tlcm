# ThinLinc Connection Manager (v2)

Native macOS app built with SwiftUI. Manage ThinLinc connections with a simple, platform-native UI.

## Requirements

- macOS 13.0 or later
- **ThinLinc Client** must be installed (the app will not start without it). Download from [Cendio](https://www.cendio.com/thinlinc/download/). Standard locations: `/Applications/ThinLinc Client.app` or `~/Applications/ThinLinc Client.app`.
- **Xcode** (full app) to build from source — Command Line Tools alone are not enough.

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
This creates **ThinLinc-Connection-Manager.dmg** in the `v2` directory. Recipients open the DMG and drag the app to Applications (or anywhere). No installer or Xcode required.

## Launching the app from the command line

```bash
open "build/Build/Products/Release/ThinLinc Connection Manager.app"
```

## Connecting to a server

- **Keyboard-first workflow:** The last connection you used is pre-selected on every launch. Press **Enter** to connect immediately, or use **↑/↓** to move the selection to a different server first, then press **Enter**.
- **Mouse:** Click **Connect** on a row, or double-click the row, to launch the client.
- **Auto-connect:** If the connection has "Connect automatically" enabled, the ThinLinc client will log in without an extra click.
- **Quit after connect:** Check "Quit after connect" in the toolbar to close TLCM automatically once the ThinLinc client is launched. This setting is remembered across restarts.

A small `.conf` file is written to `~/Library/Application Support/ThinLincConnectionManager/` each time a connection is launched.

## Managing connections

- **Add** — click **Add Connection** in the toolbar.
- **Edit** — click the **Edit** button on any row.
- **Delete** — right-click a row and choose **Delete Connection**, or use the swipe-to-delete gesture.
- **Custom icon** — drag a PNG or JPG file onto a row to use it as the icon for that connection. The image is stored alongside the settings file so it syncs with Dropbox. Right-click a row and choose **Remove Custom Icon** to revert to the default.

## Dropbox sync

On startup the app checks for Dropbox (`~/Dropbox` or `~/Library/CloudStorage/Dropbox`). If found, it uses a **single file in the Dropbox root** for all data (connections, settings, and icons):

- **File:** `tlcm-connections.json` (plus `tlcm-connections-<uuid>.png` for each custom icon)
- **Effect:** Add or edit connections on one Mac and they appear on every other Mac running the app with the same Dropbox account linked.
- The main window shows "Synced via Dropbox" under the title when this is active.
- If Dropbox is not installed, the app stores everything locally in `~/Library/Application Support/ThinLincConnectionManager/`.

## Running on another machine

- **Option A:** Copy **ThinLinc Connection Manager.app** to the other Mac (USB, AirDrop, etc.).
- **Option B:** Copy **ThinLinc-Connection-Manager.dmg**, open it on the target Mac, drag the app to Applications.
- If both machines use the same Dropbox account, connections stay in sync automatically via `tlcm-connections.json`; otherwise each Mac maintains its own local file.

## Project layout

```
ThinLincConnectionManager/
├── ThinLincConnectionManagerApp.swift   App entry point; blocks launch if ThinLinc client absent
├── ContentView.swift                    Main window: connection list, toolbar, keyboard nav
├── Models/
│   ├── Connection.swift                 Connection model (compatible with v1 JSON)
│   └── AppSettings.swift               App-wide preferences (quit-after-connect, last selection)
├── Storage/
│   ├── ConnectionsStore.swift           Load/save data (Dropbox or Application Support)
│   └── DropboxLocator.swift             Detects Dropbox installation and derives file paths
├── ThinLinc/
│   ├── ThinLincClientFinder.swift       Locates ThinLinc Client.app at launch
│   └── ThinLincClientLauncher.swift     Writes .conf and launches the client via NSWorkspace
├── Views/
│   ├── AddConnectionSheet.swift         Add / Edit connection sheet
│   ├── ConnectionIconView.swift         Displays custom icon or default SF Symbol
│   └── ThinLincNotFoundView.swift       Shown when the ThinLinc client is not installed
├── Extensions/
│   └── NSImage+Icon.swift               Resize and PNG-encode images for custom icons
└── Assets.xcassets                      App icon (Cendio.png) and accent colour
```

## Connection format

Each connection stores: `name`, `server`, `username`, `auth_type`, `auth_data`, `auto_connect`, and a UUID `id`. The JSON file also contains an `AppSettings` envelope with `quitAfterConnect` and `lastConnectedId`. The format is backward-compatible with v1 bare-array JSON files, which are automatically migrated on first open.
