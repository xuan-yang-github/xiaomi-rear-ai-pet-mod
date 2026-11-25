#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
监听 yyfish.xyz 的 DNS 状态，关键节点通过 QQ 提醒。

三个状态：
  waiting_registry  —— 注册局还没下发 NS（NXDOMAIN），刚注册的正常现象
  waiting_cloudflare—— NS 已下发但还是阿里云的，等换成 Cloudflare
  cf_ready          —— NS 已指向 Cloudflare，可以跑 setup_fixed_domain.ps1 了

用法：python watch_domain.py            （默认 120 秒一轮）
      python watch_domain.py 60        （自定义间隔）
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

DOMAIN = "yyfish.xyz"
BASE = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(BASE, "domain_watch_state.txt")
LOG_FILE = os.path.join(BASE, "domain_watch.log")

ONEBOT = "http://127.0.0.1:3000"
TOKEN = "eaJS_y0WDYNrO_L_lvknjnYH"
TARGET_UIN = 2123695580

INTERVAL = int(sys.argv[1]) if len(sys.argv) > 1 else 120


def log(msg):
    line = "[%s] %s" % (time.strftime("%m-%d %H:%M:%S"), msg)
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def send_qq(text):
    try:
        url = "%s/send_private_msg?access_token=%s" % (ONEBOT, TOKEN)
        body = json.dumps({"user_id": TARGET_UIN, "message": text}).encode("utf-8")
        req = urllib.request.Request(
            url, data=body, headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=12) as r:
            res = json.loads(r.read().decode("utf-8", "replace"))
        log("QQ sent retcode=%s" % res.get("retcode"))
        return True
    except Exception as e:
        log("QQ send failed: %r" % e)
        return False


def query_ns():
    """用阿里云 DoH 查 NS（国内最稳），返回 (status, [ns...])"""
    url = "https://dns.alidns.com/resolve?" + urllib.parse.urlencode(
        {"name": DOMAIN, "type": "NS"}
    )
    req = urllib.request.Request(url, headers={"accept": "application/dns-json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        data = json.loads(r.read().decode("utf-8", "replace"))
    status = data.get("Status", -1)
    ns = []
    for ans in data.get("Answer", []) or []:
        if ans.get("type") == 2 and ans.get("data"):
            ns.append(ans["data"].rstrip(".").lower())
    return status, sorted(set(ns))


def classify(status, ns):
    if not ns:
        return "waiting_registry"
    if any("cloudflare.com" in n for n in ns):
        return "cf_ready"
    return "waiting_cloudflare"


def read_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return ""


def write_state(s):
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            f.write(s)
    except Exception:
        pass


MESSAGES = {
    "waiting_registry": "【%s】注册局还没下发 NS（NXDOMAIN），刚买的正常，继续等。" % DOMAIN,
    "waiting_cloudflare": "【%s】NS 已下发，但还指着注册商。去 Cloudflare 拿两个 NS 回阿里云改掉。" % DOMAIN,
    "cf_ready": "【%s】NS 已指向 Cloudflare！可以切固定域名了 → pwsh -File D:\\xiaomi-rear-ai-pet\\setup_fixed_domain.ps1 -Domain %s" % (DOMAIN, DOMAIN),
}


def main():
    log("watch_domain started, domain=%s interval=%ss" % (DOMAIN, INTERVAL))
    prev = read_state()
    first = True
    while True:
        try:
            status, ns = query_ns()
            state = classify(status, ns)
            log("status=%s ns=%s -> %s" % (status, ns or "(empty)", state))
            if state != prev:
                if not first:          # 首次只记录状态，不打扰
                    send_qq(MESSAGES[state])
                write_state(state)
                prev = state
            first = False
        except Exception as e:
            log("query failed: %r" % e)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
