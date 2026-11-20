# ConfigKit platform downloads and installation

This guide covers packages published from the official ConfigKit GitHub Releases.

## Windows — EXE
1. Download ConfigKit-Windows-Setup.exe from https://github.com/huynhw19/huynhw19.github.io/releases/latest.
2. Run the installer and choose an install location.
3. Launch ConfigKit from the Start Menu or desktop shortcut.

The installer is unsigned. Windows SmartScreen may display an unknown-publisher warning. Verify that the file came from the official repository before proceeding.

## macOS — DMG
1. Download the macOS DMG matching your Mac's processor (Intel or Apple silicon) from the latest releases page.
2. Open the disk image and drag ConfigKit into Applications.
3. Eject the disk image and launch ConfigKit from Applications.

The initial app is not signed or notarized. Gatekeeper may block it. Do not bypass macOS security unless you trust the release and have checked the file.

## Linux — AppImage
1. Download the x86_64 AppImage from the latest releases page.
2. Make it executable: chmod +x ConfigKit-Linux-x64.AppImage.
3. Launch it: ./ConfigKit-Linux-x64.AppImage.

Your distribution may need FUSE support for AppImage.

## Android — APK
1. Download ConfigKit-Android.apk on your Android device.
2. Open the downloaded APK.
3. If prompted, allow the browser or file manager to install unknown apps.
4. Return to the installer and tap Install.
5. Consider turning off the install-unknown-apps permission afterwards.

The APK is a directly distributed debug-signed build, not a Google Play release. Android will show an external-source installation warning.

## iPhone and iPad — mobileconfig
ConfigKit does not ship a separate iOS app package in this release. Its iOS workflow creates Apple configuration profiles:
1. Open https://huynhw19.github.io/mobileconfig-builder.html.
2. Create your profile and select Generate & download profile.
3. Open the downloaded mobileconfig file on the iPhone or iPad.
4. Review it in Settings → Profile Downloaded, or Settings → General → VPN & Device Management.
5. Install only if you trust the source and understand every setting.

A profile can contain sensitive settings, including a Wi-Fi password. ConfigKit's browser builder creates unsigned profiles; review them before installation.

## Important notes
- Desktop and Android apps are wrappers around the hosted ConfigKit website and need an internet connection.
- Existing website features, authentication and Supabase data remain hosted; the app does not migrate or bundle user data.
- Download only from the official repository release page.
- Builds are not currently code-signed/notarized (desktop) or published through app stores.
- The iOS mobileconfig is a device configuration profile, not an iOS app installer.
