@echo off
echo Enabling Developer Mode...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"
if %errorlevel% == 0 (
    echo Developer Mode enabled successfully!
    echo Please restart your command prompt and try building again.
) else (
    echo Failed to enable Developer Mode. Please run as Administrator.
)
pause
