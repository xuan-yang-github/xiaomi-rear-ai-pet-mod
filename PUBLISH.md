# 上传到 GitHub —— 操作手册

这份文档记录**仓库已经准备好到什么程度**，以及**网络通了之后要执行的命令**。

---

## 一、现状（已完成的部分）

| 项 | 状态 |
|---|---|
| 仓库目录 | `D:\xiaomi-rear-ai-pet-publish` |
| git | portable 版装在 `D:\tmp\git\cmd\git.exe`（2.56.1，从 npmmirror 下载） |
| 初始化 | 已完成 `git init -b main` |
| 首次提交 | `bc14405 初始提交：小米妙享背屏 AI 桌宠（个人改造版）` |
| 跟踪文件 | 44 个，3.3 MB |
| README | 已重写，**顶部标明原作者 抖音 @牛霸天手机 / GitHub @nzz0991999-ai** |
| .gitignore | 已排除 cloudflared.exe（53MB）、APK、日志、备份 |
| 远程仓库 | **未创建** |
| 推送 | **未执行 —— GitHub 当前不可达（`api.github.com => 000`）** |

---

## 二、还缺什么

### 1. 网络

本机现在访问不了 GitHub 全家（TCP 通、TLS 握手成功、HTTP 层被网关 DROP）：

```
api.github.com    => 000
github.com        => 000
codeload.github.com => 000
www.baidu.com     => 200   ← 国内站正常
```

**解法**：手机 USB 共享网络给电脑（手机有流量即可），或者等校园网策略恢复。

### 2. GitHub 账号

需要两样：

- **用户名**（`github.com/<用户名>`）
- **Personal Access Token**（classic token，勾选 `repo` 权限；或 fine-grained token，勾 `Administration: write` + `Contents: write`）

生成地址：`https://github.com/settings/tokens`

> Token 只在你本地命令行里用，不会写进仓库、不会 commit。用完可以随时吊销。

---

## 三、网络通了之后的命令

把 `<USER>` 换成用户名、`<TOKEN>` 换成 token、`<REPO>` 换成仓库名（建议 `xiaomi-rear-ai-pet-mod`）。

```powershell
$git = 'D:\tmp\git\cmd\git.exe'
Set-Location 'D:\xiaomi-rear-ai-pet-publish'

# 1. 建远程仓库（用 API，免开浏览器）
$body = '{"name":"<REPO>","description":"小米妙享背屏 AI 桌宠 · 个人改造版（原作者 抖音 @牛霸天手机）","private":false,"has_issues":true}'
$headers = @{ Authorization = "Bearer <TOKEN>"; Accept = "application/vnd.github+json" }
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Method Post -Headers $headers -Body $bytes -ContentType 'application/json; charset=utf-8'

# 2. 关联远程并推送
& $git remote add origin "https://<USER>:<TOKEN>@github.com/<USER>/<REPO>.git"
& $git push -u origin main

# 3. 清掉 URL 里的 token（重要）
& $git remote set-url origin "https://github.com/<USER>/<REPO>.git"
```

---

## 四、可选：把改造版 APK 挂到 Release

APK 不进 git（`.gitignore` 已排除），走 Release 附件：

```powershell
$tag = 'v2.1.9'
$headers = @{ Authorization = "Bearer <TOKEN>"; Accept = "application/vnd.github+json" }

# 建 release
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/<USER>/<REPO>/releases" -Method Post -Headers $headers `
  -Body ([System.Text.Encoding]::UTF8.GetBytes((@{ tag_name = $tag; name = "v2.1.9 改造版"; body = "锁屏守护修复 / 无障碍保活 / 不弹主界面 / 主屏透明" } | ConvertTo-Json))) `
  -ContentType 'application/json; charset=utf-8'

# 传 APK
$apk = 'D:\xiaomi-rear-ai-pet\android\dist\MiRearPet_v2.1.9.apk'
$up = "https://uploads.github.com/repos/<USER>/<REPO>/releases/$($rel.id)/assets?name=MiRearPet_v2.1.9.apk"
Invoke-RestMethod -Uri $up -Method Post -Headers @{ Authorization = "Bearer <TOKEN>"; Accept = "application/vnd.github+json"; 'Content-Type' = 'application/vnd.android.package-archive' } -InFile $apk
```

---

## 五、仓库内容清单

```
xiaomi-rear-ai-pet-publish/
├─ README.md                     ← 重写过，含原作者声明 + 改动清单
├─ LICENSE                       ← MIT，版权保留给 @nzz0991999-ai
├─ .gitignore
├─ AGENTS.md                     ← 给 AI 读的自动化部署手册（原作者写的）
├─ TUTORIAL.md
├─ server.py                     ← 修了 getfqdn 卡死 + 完成态 TTL 60s
├─ hook_client.py / hook_manager.py
├─ keepalive.py                  ← 新增：20 秒巡检 server + cloudflared
├─ notify_tunnel.py              ← 新增：隧道域名变化通知
├─ watch_domain.py               ← 新增：域名 NS 轮询
├─ setup_fixed_domain.ps1        ← 新增：一键切 Named Tunnel
├─ qrcode_svg.py
├─ 启动背屏桌宠_8775.bat / _Windows.bat / .command
├─ Windows放行防火墙8765端口.bat
├─ 3分钟快速上手一图流.png        ← 2.9MB
├─ web/
│  ├─ index.html                 ← 轮询兜底 + 帧率闸门 + WakeLock 按状态
│  ├─ icon.svg
│  └─ manifest.json
├─ adapters/dsh-plugin/          ← DSH Cordis 插件
└─ android/
   ├─ AndroidManifest.xml        ← 加了 Theme.Translucent.NoTitleBar
   ├─ build_apk.sh
   ├─ aidl/ res/
   └─ src/com/mirearpet/         ← Java 源码（含 KeepAliveService 等）
```

注意：`android/dist/` 整个被排除。源码在 `android/src/`，要出 APK 得自己用 `build_apk.sh` 编（需要 Android SDK），或者直接用 Release 里发的已编译包。

---

## 六、版权提醒

上游是 MIT。MIT 只要求**保留原始版权声明和许可声明**，其余随便改、随便发、可以闭源商用。

所以这个仓库：

- `LICENSE` 里的 `Copyright (c) 2026 nzz0991999-ai` **必须原样保留**，不能改成自己的名字
- README 顶部写明原作者和原仓库链接 —— 这是礼貌，也是避免被当成原创
- 自己的改动可以单独声明，但不构成新的整体著作权

如果想让自己的改造部分也明确授权，可以在 README 里加一句「本仓库的修改部分同样以 MIT 发布」。
