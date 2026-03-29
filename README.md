# Simple Network Check (macOS)

A native macOS SwiftUI app for quick, parent-friendly network diagnostics.

## What it checks

- Wi-Fi on/off and associated SSID
- Local IP validity
- DHCP/default gateway presence
- Router reachability
- DNS resolution
- Internet reachability
- Wi-Fi signal quality (RSSI)

## Friendly UI

- Big **Run Check** button
- Traffic-light result cards (green/yellow/red)
- One-sentence plain-English explanation per check
- One remediation action per check
- Optional technical details via **Show Details**

## Guided actions

- Open Network settings
- Toggle Wi-Fi
- Copy DHCP renew guide
- Copy troubleshooting guide

## Report sharing

- Generate support report summary + JSON
- Share via macOS share sheet
- Copy report to clipboard

## Run in Xcode

1. Open `Package.swift` in Xcode.
2. Select the `SimpleNetworkCheck` executable scheme.
3. Run the app.

## Run tests

```bash
swift test
```

## Build Clickable App

Create install packages you can send:

```bash
make app
```

This generates:

- `dist/Simple Network Check.app` (double-clickable app)
- `dist/Simple Network Check.zip` (easy to AirDrop/email)
- `dist/Simple Network Check.dmg` (drag-to-Applications installer)

On your parents' Mac:

1. Open `Simple Network Check.dmg`.
2. Drag `Simple Network Check.app` onto `Applications`.
3. Open from `Applications`.

Optional helper in DMG:

- Double-click `Install.command` in the DMG to:
  - copy the app to `Applications`
  - remove quarantine (`xattr -dr com.apple.quarantine`) from the installed app

If Gatekeeper warns the first time:

1. Right-click the app and choose **Open**.
2. Click **Open** again in the dialog.

## Build In GitHub (Cloud)

This repo includes a GitHub Actions workflow at `.github/workflows/build-macos.yml`.

- On pushes/PRs/manual runs, it builds the app and uploads:
  - `simple-network-check-macos` artifact containing:
    - `Simple Network Check.zip`
    - `Simple Network Check.dmg`
- On tag pushes like `v1.0.0`, it also attaches both files to a GitHub Release.
- Versioning on tag builds:
  - Tag `vX.Y.Z` -> app `CFBundleShortVersionString` becomes `X.Y.Z`
  - `CFBundleVersion` uses GitHub `run_number`

Where to download:

1. GitHub -> **Actions** -> open a successful **Build macOS App** run.
2. Download artifact `simple-network-check-macos`.
3. For tags, GitHub -> **Releases** -> download `Simple Network Check.dmg`.
