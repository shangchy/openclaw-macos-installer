@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ==============================================
echo   OpenClaw (小龙虾) Windows 一键安装
echo ==============================================
echo.

REM Process-scoped Bypass so Restricted ExecutionPolicy machines still install.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-openclaw.ps1" %*
set "EC=%ERRORLEVEL%"

echo.
if not "%EC%"=="0" (
  echo 安装未成功完成，退出码: %EC%
  echo 请查看日志: %LOCALAPPDATA%\OpenClawInstaller\logs\
) else (
  echo 完成。若新开窗口找不到 openclaw，请先执行:
  echo   set PATH=%%APPDATA%%\npm;%%PATH%%
)
echo.
pause
exit /b %EC%
