@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter not found. Install Flutter SDK and add its bin folder to PATH.
  exit /b 1
)
if exist android\app\src\main\AndroidManifest.xml goto dependencies
if exist .platform_seed (
  echo Previous setup folder exists. If setup was interrupted, rename .platform_seed and retry.
  exit /b 1
)
call flutter create --platforms=android --project-name=glass_refraction_demo --org=com.example --empty --no-pub .platform_seed
if errorlevel 1 exit /b 1
robocopy ".platform_seed\android" "android" /E /NFL /NDL /NJH /NJS
if errorlevel 8 exit /b 1
:dependencies
call flutter pub get
if errorlevel 1 exit /b 1
echo Setup complete. Connect your Android phone, then run run-android.cmd
exit /b 0
