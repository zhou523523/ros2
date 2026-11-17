#!/usr/bin/env python3
"""
最小 RFB (VNC) 客户端 —— 只用 Python 标准库。
连接 Qt 的 VNC 服务端，持续抓取画面，写成 PNG，供网页实时显示。

用法:
    python3 vnc_live.py --port 59123 --out /tmp/turtle_live --fps 3
"""
import argparse
import os
import socket
import struct
import time
import zlib

PF_BPP = 32
PF_DEPTH = 24


def _recv(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("连接被对端关闭")
        buf += chunk
    return buf


def _png(w, h, rgb_rows):
    raw = b"".join(b"\x00" + row for row in rgb_rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw, 3))
            + chunk(b"IEND", b""))


class VncClient:
    def __init__(self, host, port):
        self.sock = socket.create_connection((host, port), timeout=10)
        self.sock.settimeout(20)
        self.w = self.h = 0
        self.fb = None

        ver = _recv(self.sock, 12)
        if not ver.startswith(b"RFB "):
            raise RuntimeError("不是 VNC 服务: %r" % ver)
        self.sock.sendall(b"RFB 003.003\n")

        sec = struct.unpack(">I", _recv(self.sock, 4))[0]
        if sec == 2:
            raise RuntimeError("服务端要求 VNC 密码，当前脚本不支持")
        if sec == 0:
            reason_len = struct.unpack(">I", _recv(self.sock, 4))[0]
            raise RuntimeError("服务端拒绝: %r" % _recv(self.sock, reason_len))

        self.sock.sendall(b"\x01")  # ClientInit: shared=1

        hdr = _recv(self.sock, 24)
        self.w, self.h = struct.unpack(">HH", hdr[0:4])
        name_len = struct.unpack(">I", hdr[20:24])[0]
        if name_len:
            _recv(self.sock, name_len)
        self.fb = bytearray(self.w * self.h * 4)

        # SetPixelFormat: 32bpp / 24depth / little-endian / BGRX
        pf = struct.pack(">BBBBHHHBBB3x", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
        self.sock.sendall(b"\x00\x00\x00\x00" + pf)
        # SetEncodings: 只要 Raw(0)
        self.sock.sendall(struct.pack(">BBH", 2, 0, 1) + struct.pack(">i", 0))

        self.first = True

    def request(self):
        inc = 0 if self.first else 1
        self.sock.sendall(struct.pack(">BBHHHH", 3, inc, 0, 0, self.w, self.h))
        self.first = False

    def read_update(self):
        while True:
            mt = _recv(self.sock, 1)[0]
            if mt == 0:                      # FramebufferUpdate
                _recv(self.sock, 1)
                n = struct.unpack(">H", _recv(self.sock, 2))[0]
                for _ in range(n):
                    x, y, w, h = struct.unpack(">HHHH", _recv(self.sock, 8))
                    enc = struct.unpack(">i", _recv(self.sock, 4))[0]
                    if enc != 0:
                        raise RuntimeError("未预期的编码类型 %d" % enc)
                    pix = _recv(self.sock, w * h * 4)
                    stride = self.w * 4
                    for row in range(h):
                        src = row * w * 4
                        dst = (y + row) * stride + x * 4
                        self.fb[dst:dst + w * 4] = pix[src:src + w * 4]
                return True
            if mt == 1:                      # SetColourMapEntries
                _recv(self.sock, 1)
                _, ncol = struct.unpack(">HH", _recv(self.sock, 4))
                _recv(self.sock, ncol * 6)
            elif mt == 2:                    # Bell
                pass
            elif mt == 3:                    # ServerCutText
                _recv(self.sock, 3)
                ln = struct.unpack(">I", _recv(self.sock, 4))[0]
                _recv(self.sock, ln)
            else:
                raise RuntimeError("未知消息类型 %d" % mt)

    def _content_box(self):
        """找出实际有内容的区域（左上角对齐），裁掉四周的黑色空白。"""
        stride = self.w * 4
        zero = bytes(stride)
        right = 0
        bottom = 0
        for y in range(self.h):
            row = bytes(self.fb[y * stride:(y + 1) * stride])
            if row != zero:
                bottom = y + 1
                # 从右往左找该行最后一个非零像素
                for x in range(self.w - 1, right - 1, -1):
                    px = row[x * 4:x * 4 + 4]
                    if px != b"\x00\x00\x00\x00":
                        if x + 1 > right:
                            right = x + 1
                        break
        if right == 0 or bottom == 0:
            return self.w, self.h
        return right, bottom

    def to_png(self, crop=True):
        stride = self.w * 4
        cw, ch = self._content_box() if crop else (self.w, self.h)
        rows = []
        for y in range(ch):
            mv = self.fb[y * stride:y * stride + cw * 4]
            row = bytearray(cw * 3)
            row[0::3] = mv[2::4]
            row[1::3] = mv[1::4]
            row[2::3] = mv[0::4]
            rows.append(bytes(row))
        return _png(cw, ch, rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--fps", type=float, default=3.0)
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    target = os.path.join(args.out, "turtle.png")
    tmp = target + ".tmp"
    interval = 1.0 / max(0.5, args.fps)

    print("连接 VNC %s:%d ..." % (args.host, args.port), flush=True)
    while True:
        try:
            cli = VncClient(args.host, args.port)
            print("已连接，画面 %dx%d" % (cli.w, cli.h), flush=True)
            while True:
                t0 = time.time()
                cli.request()
                cli.read_update()
                data = cli.to_png()
                with open(tmp, "wb") as f:
                    f.write(data)
                os.replace(tmp, target)
                rest = interval - (time.time() - t0)
                if rest > 0:
                    time.sleep(rest)
        except (ConnectionError, socket.timeout, OSError, RuntimeError) as e:
            print("中断: %s，2 秒后重连" % e, flush=True)
            time.sleep(2)


if __name__ == "__main__":
    main()
