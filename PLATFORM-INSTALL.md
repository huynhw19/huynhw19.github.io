# ConfigKit platform downloads and installation

This guide covers packages published from the official ConfigKit GitHub Releases.

## Windows — EXE
1. Download ConfigKit-Windows-Setup.exe from https://github.com/huynhw19/huynhw19.github.io/releases/latest.
2. Run the installer and choose an install location.
3. Launch ConfigKit from the Start Menu or desktop shortcut.

The installer is unsigned. Windows SmartScreen may display an unknown-publisher warning. Verify that the file came from the official repository before proceeding.

## macOS — DMG
1. Download ConfigKit-macOS-arm64.dmg for Apple silicon or ConfigKit-macOS-x64.dmg for Intel from the [latest releases](https://github.com/huynhw19/huynhw19.github.io/releases/latest).
2. Open the disk image and drag ConfigKit into Applications.
3. Eject the disk image and launch ConfigKit from Applications.

The initial app is not signed or notarized. Gatekeeper may block it. Do not bypass macOS security unless you trust the release and have checked the file.

## Linux — AppImage
1. Download [ConfigKit-Linux-x64.AppImage](https://github.com/huynhw19/huynhw19.github.io/releases/latest/download/ConfigKit-Linux-x64.AppImage).
2. Make it executable: chmod +x ConfigKit-Linux-x64.AppImage.
3. Launch it: ./ConfigKit-Linux-x64.AppImage.

Your distribution may need FUSE support for AppImage.

## Android — APK
1. Download ConfigKit-Android.apk on your Android device.
2. Open the downloaded APK.
3. If prompted, allow the browser or file manager to install unknown apps.
4. Return to the installer and tap Install.
5. Consider turning off the install-unknown-apps permission afterwards.

The APK is signed with Android's standard debug certificate for direct testing and distribution, not a private production signing key or Google Play. Android will show an external-source installation warning. Do not use this build for high-assurance enterprise deployment.

## iPhone and iPad — mobileconfig
ConfigKit does not ship a separate iOS app package in this release. Its iOS workflow creates Apple configuration profiles:
1. Open https://huynhw19.github.io/mobileconfig-builder.html and sign in to your ConfigKit account.
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
