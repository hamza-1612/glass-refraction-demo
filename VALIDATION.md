# Validation — 2026-09-10

Executed successfully:
- Compiled/rendered the bundled GLSL through the host EGL/OpenGL harness.
- 31 assertions passed, including edge displacement, identity, calm center,
  backdrop movement, DPR scaling, GLES orientation branch and premultiplied alpha.
- Inspected the resulting light/dark contact sheet.

See `evidence/shader-results.json` and `evidence/shader-preview.png`.
These images are diagnostic host shader renders, NOT screenshots of the Flutter app.

Not executed in this environment (Flutter/Dart SDK and Android device unavailable):
- Dart formatting/static analysis of this delivered UI revision.
- Flutter widget tests and integration test.
- Flutter shader compiler / Android APK build.
- Windows command-script execution.
- Real Impeller backdrop alignment, clipping and performance on Android.

The included source is an experimental demo, not a device-validated build.
The Android platform wrapper is generated on the user's computer by setup-android.cmd.
Test the actual device with the steps in README_AR.md before integrating into an app.
