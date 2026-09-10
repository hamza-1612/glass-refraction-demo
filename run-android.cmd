@echo off
setlocal
cd /d "%~dp0"
if not exist android\app\src\main\AndroidManifest.xml (
  echo Run setup-android.cmd first.
  exit /b 1
)
if "%~1"=="" (
  call flutter devices
  echo Select your ANDROID phone if Flutter asks you to choose a device.
  call flutter run --enable-impeller
) else (
  call flutter run --enable-impeller -d "%~1"
)
exit /b %errorlevel%
