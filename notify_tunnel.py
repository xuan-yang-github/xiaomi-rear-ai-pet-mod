# -*- coding: utf-8 -*-
"""监视 cloudflared quick tunnel 的域名，变了就发 QQ 提醒。

cloudflared 免费 quick tunnel 每次重启域名都会换，手机端就得重新填地址。
这个脚本常驻轮询 tunnel.log，发现新域名立刻推到你 QQ，省得天天问。
"""
from __future__ import annotations

import json
import pathlib
import re
import time
import urllib.request

BASE = pathlib.Path(r"D:\xiaomi-rear-ai-pet")
LOG = BASE / "tunnel.log"
STATE = BASE / "last_tunnel_url.txt"
OUT = BASE / "notify_tunnel.log"

QQ = "2123695580"
API = "http://127.0.0.1:3000"
TOKEN = "eaJS_y0WDYNrO_L_lvknjnYH"
PAT = re.compile(r"https://([a-z0-9-]+)\.trycloudflare\.com")
INTERVAL = 30


def log(s: str) -> None:
    try:
        with OUT.open("a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + str(s) + "\n")
    except OSError:
        pass


def latest_url() -> str | None:
    try:
        txt = LOG.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    hits = PAT.findall(txt)
    return hits[-1] if hits else None


def send(msg: str) -> dict:
    body = json.dumps({"user_id": int(QQ), "message": msg}, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        API + "/send_private_msg?access_token=" + TOKEN,
        data=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode("utf-8"))


def main() -> None:
    log("notify_tunnel started")
    last = None
    if STATE.exists():
        last = STATE.read_text(encoding="utf-8").strip() or None

    while True:
        url = latest_url()
        if url and url != last:
            head = "隧道地址已更新" if last else "隧道地址已就绪"
            msg = (
                f"【背屏桌宠】{head}：\n"
                f"https://{url}/\n\n"
                f"在 App「1. 连接电脑」框里填这个地址，再点「一键投到妙享背屏」。"
            )
            try:
                r = send(msg)
                if r.get("retcode") == 0:
                    last = url
                    STATE.write_text(url + "\n", encoding="utf-8")
                    log(f"sent {url}")
                else:
                    log(f"send rejected {url} retcode={r.get('retcode')}")
            except Exception as e:  # noqa: BLE001
                log(f"send failed: {e}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
