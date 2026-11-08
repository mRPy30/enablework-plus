# Android validation and Git publication follow-up

The owner explicitly approved committing all Phase 1 changes and a normal push to main. No force-push, history rewrite, production/Supabase deployment or Phase 2 implementation is authorized.

## Observed Android results

- Installed AVD: Medium_Phone_API_37.0, emulator 37.2.13.0, x86_64 API 37 Play Store image.
- Launch attempted with -no-snapshot-save. It exited because hardware acceleration was unavailable to this process.
- -accel-check returned code 6 and a Hyper-V/Windows Hypervisor Platform diagnostic. This does not establish whether normal Android Studio outside the sandbox can use acceleration.
- The owner subsequently reported the AVD fully booted in ordinary Windows. This session still sees no devices through ADB, and direct loopback ADB connection was refused. No app startup or mobile Auth success has been observed by the agent.
- Desktop inspection found Android Studio open on C:\Users\Janvier\StudioProjects\enablework-plus, a different checkout from the authorized C:\Users\Janvier\enablework-plus. No project content was changed in that other checkout.
- Two debug builds attempted using the installed Android Studio JDK and an ignored, writable local Gradle cache. Both failed while fetching Gradle 9.3.1-all with HTTP 504, before application compilation. The alternate official distribution endpoint was also unavailable from this session.
- Full mobile Auth still requires the local Supabase runtime and real local public client settings; Docker/Podman and that runtime were absent in the prior assessment. Passing offline tests does not establish a live Auth flow.

## Start the existing AVD in ordinary Windows

Android Studio: Device Manager -> select Medium_Phone_API_37.0 -> Start. Alternatively, in ordinary Windows PowerShell:

```powershell
& 'C:\Users\Janvier\AppData\Local\Android\sdk\emulator\emulator.exe' -avd Medium_Phone_API_37.0 -no-snapshot-save
```

Use another PowerShell window for:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus\mobile'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio1\jbr'
$env:Path = "C:\flutter\bin;$env:JAVA_HOME\bin;$env:Path"
flutter devices
$androidDeviceId = Read-Host 'Enter the Android device ID shown above'
if ([string]::IsNullOrWhiteSpace($androidDeviceId)) { throw 'A running Android device is required.' }
flutter run -d $androidDeviceId
```

Without configured local Supabase settings this validates only the setup screen/startup. Once the local backend is running and config/local/mobile.json contains its public key, use:

```powershell
flutter run -d $androidDeviceId --dart-define-from-file=../config/local/mobile.json
```

Validate registration, email confirmation, login, forbidden administrator access in the mobile app, logout/restart/session behavior, recovery and suspension. Do not enter real PWD details. See phase-1-local-setup.md for backend setup and callback/adb-reverse instructions.

If the AVD also fails in ordinary Windows, run -accel-check there and follow the official acceleration instructions. Do not infer that Windows features need changing solely from this sandboxed launch failure.

https://developer.android.com/studio/run/emulator-acceleration

## Git publication boundary

Branch is main; origin is https://github.com/mRPy30/enablework-plus.git. Existing scaffold commit 60f1140 is preserved. The normal Git credential-helper shell fails in this process with NtCreateDirectoryObject access denied. Direct invocation of the existing GitHub CLI helper is also unavailable here. No new login was attempted and no credential values were displayed or saved.

The owner has authorized a separate Phase 1 commit. After it exists, a normal push can be run from the already authenticated ordinary Windows PowerShell if this environment cannot publish:

```powershell
Set-Location 'C:\Users\Janvier\enablework-plus'
git status --short --branch
git remote -v
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Fetch failed; stop.' }
git merge-base --is-ancestor origin/main HEAD
if ($LASTEXITCODE -ne 0) { throw 'Remote contains divergent work; inspect before proceeding.' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed; do not force it.' }
git rev-parse HEAD
git ls-remote origin refs/heads/main
git log -2 --oneline
```

Local HEAD and the remote main hash must match. Do not create a duplicate commit. Emulator verification and live push verification are still prerequisites to the requested Phase 2 planning handoff.
