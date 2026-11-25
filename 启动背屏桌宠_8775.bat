@echo off
rem 小米妙享背屏 AI 桌宠 · 全套启动
rem   1) 状态服务 8775（8765 被手机控制服务占着）
rem   2) cloudflared 公网隧道（域名每次重启会变）
rem   3) 隧道域名变化自动推 QQ
rem   4) 域名 NS 监听（注册局一发布就推 QQ）
rem 重复执行不会起两份服务
set BASE=D:\xiaomi-rear-ai-pet
set PY=D:\大肥鱼\runtime\python312\pythonw.exe

netstat -ano | findstr /C:":8775" | findstr /I "LISTENING" >nul 2>&1
if errorlevel 1 (
  start "" /min "%PY%" -X utf8 "%BASE%\server.py" --host 0.0.0.0 --port 8775
)

tasklist /FI "IMAGENAME eq cloudflared.exe" 2>nul | findstr /I "cloudflared.exe" >nul 2>&1
if errorlevel 1 (
  start "" /min "%BASE%\cloudflared.exe" tunnel --url http://127.0.0.1:8775 --no-autoupdate --protocol http2 --logfile "%BASE%\tunnel.log" --loglevel info
)

powershell -NoProfile -WindowStyle Hidden -Command "$p=Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe'\" | Where-Object { $_.CommandLine -like '*notify_tunnel.py*' }; if(-not $p){ Start-Process -FilePath '%PY%' -ArgumentList '-X','utf8','%BASE%\notify_tunnel.py' -WindowStyle Hidden }"

rem 4) 域名 NS 监听：以前只在手动起的进程里跑，机器一重启就丢，发布那天没人会知道
powershell -NoProfile -WindowStyle Hidden -Command "$p=Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe'\" | Where-Object { $_.CommandLine -like '*watch_domain.py*' }; if(-not $p){ Start-Process -FilePath '%PY%' -ArgumentList '-X','utf8','%BASE%\watch_domain.py' -WindowStyle Hidden }"

timeout /t 3 >nul
start "" "http://127.0.0.1:8775/?preview=1"