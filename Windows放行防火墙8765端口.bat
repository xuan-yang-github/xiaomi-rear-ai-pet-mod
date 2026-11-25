@echo off
chcp 65001 >nul
echo 正在为「背屏 AI 桌宠」放行 Windows 防火墙端口 (TCP 8765 / UDP 8766)...
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo 正在请求管理员权限...
  powershell -Command "Start-Process '%~f0' -Verb RunAs"
  exit /b
)

netsh advfirewall firewall delete rule name="MiRearPet HTTP 8765" >nul 2>&1
netsh advfirewall firewall delete rule name="MiRearPet Discovery UDP 8766" >nul 2>&1
netsh advfirewall firewall add rule name="MiRearPet HTTP 8765" dir=in action=allow protocol=TCP localport=8765
netsh advfirewall firewall add rule name="MiRearPet Discovery UDP 8766" dir=in action=allow protocol=UDP localport=8766

echo.
echo [完成] 已放行端口 TCP 8765 与 UDP 8766，手机同 Wi-Fi 下现在可以正常连接电脑！
pause
