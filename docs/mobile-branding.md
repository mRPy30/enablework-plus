# Mobile brand integration

The approved EnableWork+ identity is applied to the Android job-seeker application.

- Source artwork: `mobile/assets/branding/`. Editable and outlined SVG masters are retained; Flutter uses the transparent high-resolution PNG without adding an SVG dependency.
- Native launch before Android 12: white background with a centered full logo, name and tagline, exported for each Android density.
- Android 12+: white background and a padded symbol to respect the platform splash mask. The full lockup appears during Flutter configuration/Auth-storage initialization and on the sign-in/setup screen. No artificial splash timer is used.
- Launcher: legacy density icons and Android 8+ adaptive foreground/background, with padding for common launcher masks.
- UI: royal-blue theme seed; existing dark theme, high contrast, reduced motion and system text scaling remain available. The logo keeps a white backing for legibility and exposes a single spoken brand/tagline label.

Android splash sizing reference: [Android Developers](https://developer.android.com/develop/ui/views/launch/splash-screen).

The splash image does not contain a phone frame. Native assets are separate from the presentation mockup. No permissions, account rules, Auth callbacks, database policies or backend credentials are changed.

## Preview

Stop the current Flutter process with `q`, then run from the existing checkout:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus\mobile'
flutter pub get
flutter devices
$androidDeviceId = Read-Host 'Android device ID from flutter devices'
if ([string]::IsNullOrWhiteSpace($androidDeviceId)) { throw 'Android device required.' }
flutter run -d $androidDeviceId
```

If a working ignored local connection file already exists, preserve the same launch defines used previously:

```powershell
flutter run -d $androidDeviceId --dart-define-from-file=../config/local/mobile.json
```

A full stop/build/run is required for native resource and launcher changes. Hot reload alone does not update those. Test cold launches in both OS appearance modes and check circular and squircle launcher masks on a device. Some launchers cache icons until their next refresh.

## Validation in this session

- Android density artwork inspected; all Android XML parses.
- AAPT2 compiled all app resources and linked them against Android API 36 successfully. This checks resources, not a complete APK or emulator startup.
- Flutter analyzer: PASS, no issues, rerun before the approved Git publication.
- The first runnable widget suite exposed the previous teal-theme expectation; that expectation was updated to the approved blue seed. The preview-export test was also corrected to perform rendering in runAsync.
- The earlier session encountered Windows invalid-handle errors; the subsequent publication validation completed successfully: all 38 mobile tests PASS, including both branding tests.
- The Flutter startup widget was rendered and visually inspected; it is not an emulator screenshot.
- git diff --check passes. The owner subsequently authorized committing and pushing the Phase 2 and branding changes. No new secret, hosted Supabase configuration or deployment is included.
