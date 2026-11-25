#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""背屏桌宠保活：server.py(8775) 与 cloudflared 隧道，缺哪个补哪个。

背景：cloudflared 曾被上游进程树连带杀死（tunnel.log 里
"Initiating graceful shutdown due to signal terminated"），
导致公网域名失效、手机端 connected_phones 掉到 0。
本脚本由 pythonw 独立运行，用 DETACHED_PROCESS 拉起子进程，
避免再次被上层工具回收。
"""
import os
import socket
import subprocess
import sys
import time

BASE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
LOG = os.path.join(BASE, "keepalive.log")
TUNNEL_LOG = os.path.join(BASE, "tunnel.log")
PORT = int(os.environ.get("MI_REAR_PET_PORT", "8775"))
INTERVAL = 20
DETACHED = 0x00000008
NO_WINDOW = 0x08000000


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + msg
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def port_open(port=PORT):
    s = socket.socket()
    s.settimeout(1.5)
    try:
        s.connect(("127.0.0.1", port))
        return True
    except Exception:
        return False
    finally:
        try:
            s.close()
        except Exception:
            pass


def cloudflared_alive():
    try:
        out = subprocess.check_output(
            ["tasklist", "/FI", "IMAGENAME eq cloudflared.exe", "/NH"],
            creationflags=NO_WINDOW, text=True, encoding="gbk", errors="ignore")
    except Exception:
        return False
    return "cloudflared.exe" in out


def _spawn(args):
    devnull = open(os.devnull, "w")
    return subprocess.Popen(
        args, cwd=BASE, creationflags=DETACHED,
        stdout=devnull, stderr=devnull, stdin=devnull,
        close_fds=True)


def start_server():
    log("server 未监听 %d，启动" % PORT)
    _spawn([PY, "-X", "utf8", os.path.join(BASE, "server.py"),
            "--host", "0.0.0.0", "--port", str(PORT)])


def start_tunnel():
    log("cloudflared 不在，启动隧道")
    _spawn([os.path.join(BASE, "cloudflared.exe"), "tunnel",
            "--url", "http://127.0.0.1:%d" % PORT,
            "--no-autoupdate", "--protocol", "http2",
            "--logfile", TUNNEL_LOG, "--loglevel", "info"])


def main():
    log("keepalive started pid=%d interval=%ds port=%d" % (os.getpid(), INTERVAL, PORT))
    while True:
        try:
            if not port_open():
                start_server()
                time.sleep(4)
            if not cloudflared_alive():
                start_tunnel()
                time.sleep(8)
        except Exception as exc:
            log("watch error: %r" % (exc,))
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
