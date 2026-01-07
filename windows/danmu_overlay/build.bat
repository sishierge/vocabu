@echo off
REM Build script for DanmuOverlay WPF project
REM Produces an optimized single-file executable

echo Building DanmuOverlay...

REM Clean previous builds
if exist "bin" rd /s /q "bin"
if exist "obj" rd /s /q "obj"

REM Build and publish
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -p:DebugType=None -p:DebugSymbols=false -o "bin\publish"

if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b 1
)

echo.
echo Build successful!
echo Output: bin\publish\DanmuOverlay.exe

REM Show file size
for %%A in ("bin\publish\DanmuOverlay.exe") do (
    set size=%%~zA
    echo File size: %%~zA bytes
)

echo.
echo To deploy, copy DanmuOverlay.exe to your Flutter app's output directory.
