@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo   Mi 17 Pro Max 背屏 AI 桌宠 · Windows 一键启动
echo ============================================================

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 server.py --open
  goto :end
)

where python >nul 2>nul
if %errorlevel%==0 (
  python server.py --open
  goto :end
)

where python3 >nul 2>nul
if %errorlevel%==0 (
  python3 server.py --open
  goto :end
)

echo.
echo [提示] 未检测到 Python 3。
echo 请先在 Microsoft Store 或 https://www.python.org/downloads/ 安装 Python 3（安装时勾选 Add Python to PATH），然后重新双击本脚本。
echo.
pause
:end
