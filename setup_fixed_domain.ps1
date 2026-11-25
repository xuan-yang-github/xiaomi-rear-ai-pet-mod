<#
  背屏 AI 桌宠 —— 把临时隧道换成固定域名（Cloudflare Named Tunnel）

  前置条件：
    1. 已买到域名，并且已经把 NS 改到 Cloudflare，CF 后台显示 Active
    2. 本机已装 cloudflared.exe（本目录下就有）
    3. 有浏览器可以点授权

  用法：
    pwsh -File D:\xiaomi-rear-ai-pet\setup_fixed_domain.ps1 -Domain abc.top
    pwsh -File D:\xiaomi-rear-ai-pet\setup_fixed_domain.ps1 -Domain abc.top -Sub dsh
#>
param(
    [Parameter(Mandatory = $true)][string]$Domain,
    [string]$Sub = "pet",
    [int]$Port = 8775
)

$ErrorActionPreference = "Stop"
$Base = "D:\xiaomi-rear-ai-pet"
$cf = Join-Path $Base "cloudflared.exe"
$TunnelName = "rear-pet"
$HostName = "$Sub.$Domain"
$CfDir = Join-Path $env:USERPROFILE ".cloudflared"
$CertPem = Join-Path $CfDir "cert.pem"

function Say($msg, $color = "Cyan") { Write-Host "  $msg" -ForegroundColor $color }

Write-Host "`n=== 1. 检查 cloudflared ===" -ForegroundColor Green
if (-not (Test-Path $cf)) { throw "找不到 $cf" }
& $cf --version | Select-Object -First 1 | ForEach-Object { Say $_ }

Write-Host "`n=== 2. Cloudflare 授权（需要点浏览器）===" -ForegroundColor Green
if (Test-Path $CertPem) {
    Say "已存在 cert.pem，跳过登录" "DarkGray"
} else {
    Say "即将打开浏览器，登录 Cloudflare 后选择 $Domain 这个站点，点 Authorize" "Yellow"
    Read-Host "  按回车开始"
    & $cf tunnel login
    if (-not (Test-Path $CertPem)) { throw "登录未完成：没有生成 cert.pem" }
    Say "登录成功" "Green"
}

Write-Host "`n=== 3. 创建/复用隧道 $TunnelName ===" -ForegroundColor Green
$json = & $cf tunnel list --output json 2>$null
$tunnels = @()
if ($json) { try { $tunnels = $json | ConvertFrom-Json } catch { $tunnels = @() } }
$t = $tunnels | Where-Object { $_.name -eq $TunnelName } | Select-Object -First 1
if (-not $t) {
    Say "新建隧道..." "Yellow"
    & $cf tunnel create $TunnelName | ForEach-Object { Say $_ "DarkGray" }
    $json = & $cf tunnel list --output json 2>$null
    $tunnels = $json | ConvertFrom-Json
    $t = $tunnels | Where-Object { $_.name -eq $TunnelName } | Select-Object -First 1
}
if (-not $t) { throw "隧道创建失败" }
$uuid = $t.id
Say "隧道 ID: $uuid" "Green"

Write-Host "`n=== 4. 绑定域名 $HostName ===" -ForegroundColor Green
& $cf tunnel route dns $TunnelName $HostName 2>&1 | ForEach-Object { Say $_ "DarkGray" }

Write-Host "`n=== 5. 写 config.yml ===" -ForegroundColor Green
$credFile = Join-Path $CfDir "$uuid.json"
if (-not (Test-Path $credFile)) { throw "找不到凭证文件 $credFile" }
$cfg = @"
tunnel: $uuid
credentials-file: $credFile

ingress:
  - hostname: $HostName
    service: http://127.0.0.1:$Port
  - service: http_status:404
"@
$cfgPath = Join-Path $Base "config.yml"
[System.IO.File]::WriteAllText($cfgPath, $cfg, (New-Object System.Text.UTF8Encoding($false)))
Say "已写入 $cfgPath" "Green"

Write-Host "`n=== 6. 停掉临时隧道 ===" -ForegroundColor Green
Get-Process cloudflared -ErrorAction SilentlyContinue | ForEach-Object {
    Say "结束 cloudflared PID $($_.Id)" "DarkGray"
    Stop-Process -Id $_.Id -Force
}
Start-Sleep -Seconds 2

Write-Host "`n=== 7. 启动固定隧道 ===" -ForegroundColor Green
Start-Process -FilePath $cf `
    -ArgumentList "tunnel", "--config", $cfgPath, "run", "--protocol", "http2", "--logfile", (Join-Path $Base "tunnel.log") `
    -WorkingDirectory $Base -WindowStyle Hidden
Start-Sleep -Seconds 6

Write-Host "`n=== 8. 验证 ===" -ForegroundColor Green
$ok = $false
foreach ($i in 1..6) {
    try {
        $r = Invoke-WebRequest -Uri "https://$HostName/api/info" -TimeoutSec 12 -UseBasicParsing
        if ($r.StatusCode -eq 200) { Say "✔ https://$HostName/api/info 已通（$($r.Content.Substring(0,[Math]::Min(120,$r.Content.Length)))）" "Green"; $ok = $true; break }
    } catch {
        Say "第 $i 次没通，等 5 秒重试..." "DarkGray"
        Start-Sleep -Seconds 5
    }
}
if (-not $ok) { Say "域名还没通。常见原因：CF 后台还没 Active / DNS 未生效 / NS 没改对。" "Red" }

Write-Host "`n=== 9. 更新开机启动脚本 ===" -ForegroundColor Green
$batPath = Join-Path $Base "启动背屏桌宠_8775.bat"
$bat = @"
@echo off
chcp 65001 >nul
set "BASE=D:\xiaomi-rear-ai-pet"
set "PY=D:\大肥鱼\runtime\python312\pythonw.exe"

netstat -ano | findstr /C:":$Port" | findstr /I "LISTENING" >nul
if errorlevel 1 (
    start "" "%PY%" -X utf8 "%BASE%\server.py" --host 0.0.0.0 --port $Port
    timeout /t 3 /nobreak >nul
)

tasklist /FI "IMAGENAME eq cloudflared.exe" 2>nul | findstr /I "cloudflared.exe" >nul
if errorlevel 1 (
    start "" "%BASE%\cloudflared.exe" tunnel --config "%BASE%\config.yml" run --protocol http2 --logfile "%BASE%\tunnel.log"
    timeout /t 3 /nobreak >nul
)

timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:$Port/?preview=1"
"@
[System.IO.File]::WriteAllText($batPath, $bat, (New-Object System.Text.UTF8Encoding($false)))
Say "已更新 $batPath（改成走 config.yml，不再随机域名）" "Green"

Write-Host "`n完成。手机里填： https://$HostName/" -ForegroundColor Cyan
Write-Host "这个地址以后不会再变。`n" -ForegroundColor Cyan
