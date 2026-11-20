# ConfigKit for Windows

ConfigKit for Windows is an Electron desktop shell for the existing hosted ConfigKit website.

## What it does

- Opens [https://huynhw19.github.io/](https://huynhw19.github.io/) in a standalone desktop window.
- Keeps the existing web application, Supabase authentication, and backend; it does not duplicate or migrate user data.
- Uses a persistent application browser profile so normal web sign-in sessions can be retained.
- Provides desktop menus, reload, zoom and full-screen controls.
- Creates Start Menu and optional desktop shortcuts through the Windows installer.

An internet connection is required. This first version is a desktop wrapper, not an offline copy of the website. The installer is not code-signed; Windows may show a SmartScreen unknown-publisher notice.

## Download the installer

1. Open the repository's **Actions** tab.
2. Select **Windows desktop app**.
3. Choose **Run workflow** on the `main` branch.
4. Wait for the **build-windows** job to finish successfully.
5. Open the completed run and download **ConfigKit-Windows-Installer** from Artifacts.
6. Extract the artifact ZIP and run the `ConfigKit-Setup-...`.exe installer.

Workflow artifacts are retained for 30 days. To publish a persistent versioned download, push a version tag such as `v1.0.0`; the workflow will attach the installer to a GitHub Release.

## Build locally

Requires Node.js 22 and Windows.

```powershell
npm install
npm run dist:win
```

The installer is written to `release/`.

## Security notes

- Electron Node.js integration is disabled in the website renderer.
- Context isolation, sandboxing and web security are enabled.
- Only HTTP(S) links can be opened as external windows.
- The desktop wrapper does not contain Supabase service-role credentials or any private application secrets.
- The website and its existing server-side access controls remain responsible for authentication and authorization.

## Current scope

This package loads the live website in an Electron window. It does not currently bundle the website for offline use, implement an auto-updater, or provide a signed Windows installer. The GitHub Actions build must complete successfully before an installer is available to download.
