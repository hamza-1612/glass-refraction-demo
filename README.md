# Glass refraction demo

Standalone Flutter / Android experiment using live backdrop refraction,
floating capsule navigation and a flat multitone circular action.
This repository is separate from the pharmacy project.

## Download on Android

Open [Actions](https://github.com/hamza-1612/glass-refraction-demo/actions),
then the latest successful **Build Android APK** run. Under **Artifacts**:

- `glass-demo-arm64`: most modern ARM Android phones.
- `glass-demo-arm32`: older 32-bit ARM Android devices.

Download the artifact while signed into GitHub, extract its ZIP on the phone,
then open the APK. These are experimental apps signed with the generated
Flutter template's debug key even though compiled in release mode, not
store-distribution builds. Different runs may use different debug keys; Android
may require uninstalling a previous demo before installing a later one.
This demo does not store user data.

Artifacts expire after seven days. Use **Run workflow** to rebuild when needed.
The workflow has a 30-minute limit and does not change Actions billing settings.
If account quotas or permissions block the job, the owner must resolve them.

`refractive` indicates the shader path; `frostedFallback` indicates blur only.
Real-device visual inspection remains necessary even after successful builds.
See [Arabic instructions](README_AR.md) and [validation limits](VALIDATION.md).

## Local setup

Windows: run `setup-android.cmd`, then `run-android.cmd` with your Android phone
connected. Requires Flutter >=3.44 and Android development tools.
Visual Studio's Windows C++ workload is not needed for Android.

The wrapper is generated from the installed Flutter SDK, without replacing
the actual Dart source or tests. The cloud build uses latest stable Flutter;
the minimum version in pubspec rejects an incompatible SDK.
