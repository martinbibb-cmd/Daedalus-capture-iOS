#!/usr/bin/env python3
import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "DaedalusScan" / "App" / "Assets.xcassets" / "AppIcon.appiconset"
LOGO_DIR = ROOT / "DaedalusScan" / "App" / "Assets.xcassets" / "DaedalusLogo.imageset"


def write_png(path, width, height, pixels):
    def chunk(kind, data):
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    for y in range(height):
        raw.append(0)
        start = y * width * 3
        raw.extend(pixels[start:start + width * 3])

    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(data)


def mix(a, b, t):
    return int(a + (b - a) * t)


def smoothstep(edge0, edge1, x):
    if edge0 == edge1:
        return 1.0 if x >= edge1 else 0.0
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def blend(base, top, alpha):
    return tuple(mix(base[i], top[i], alpha) for i in range(3))


def icon_pixel(x, y, size):
    nx = x / (size - 1)
    ny = y / (size - 1)
    radial = math.hypot(nx - 0.78, ny - 0.22)
    t = min(1.0, max(0.0, (nx * 0.75 + ny * 0.55 + radial * 0.25)))
    base = (mix(10, 28, t), mix(39, 112, t), mix(78, 132, t))
    glow = max(0.0, 1.0 - math.hypot(nx - 0.68, ny - 0.32) * 2.2)
    base = blend(base, (22, 197, 190), glow * 0.35)

    grid = 0.0
    for p in (0.24, 0.39, 0.54, 0.69):
        grid = max(grid, 1.0 - abs(nx - p) * size / 1.25)
        grid = max(grid, 1.0 - abs(ny - p) * size / 1.25)
    base = blend(base, (128, 222, 214), max(0.0, min(1.0, grid)) * 0.14)

    # Vector-friendly Daedalus "D": a vertical stem with an elliptical scan arc.
    stem = smoothstep(0.155, 0.145, abs(nx - 0.32)) * smoothstep(0.31, 0.33, ny) * smoothstep(0.77, 0.75, ny)
    cx, cy = 0.42, 0.54
    ex, ey = (nx - cx) / 0.34, (ny - cy) / 0.27
    radius = math.hypot(ex, ey)
    arc = smoothstep(0.115, 0.09, abs(radius - 1.0)) * smoothstep(0.30, 0.34, nx) * smoothstep(0.74, 0.70, nx)
    cut = smoothstep(0.82, 0.80, radius)
    mark = max(stem, arc * cut)
    base = blend(base, (245, 252, 255), mark)

    scan = smoothstep(0.018, 0.0, abs(ny - 0.54)) * smoothstep(0.20, 0.26, nx) * smoothstep(0.82, 0.76, nx)
    base = blend(base, (67, 230, 212), scan * 0.78)
    return base


def render_square(path, size):
    pixels = bytearray()
    samples = 1 if size >= 512 else 2
    for y in range(size):
        for x in range(size):
            acc = [0, 0, 0]
            for sy in range(samples):
                for sx in range(samples):
                    px = x + (sx + 0.5) / samples
                    py = y + (sy + 0.5) / samples
                    c = icon_pixel(px, py, size)
                    acc[0] += c[0]
                    acc[1] += c[1]
                    acc[2] += c[2]
            scale = samples * samples
            pixels.extend([acc[0] // scale, acc[1] // scale, acc[2] // scale])
    write_png(path, size, size, pixels)


def render_logo(path, width, height):
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            nx = x / (width - 1)
            ny = y / (height - 1)
            bg = (10, 34, 64)
            line = smoothstep(0.012, 0.0, abs(ny - 0.5)) * smoothstep(0.07, 0.12, nx) * smoothstep(0.93, 0.88, nx)
            bg = blend(bg, (40, 211, 196), line * 0.9)
            cx, cy = 0.18, 0.5
            ring = smoothstep(0.028, 0.0, abs(math.hypot((nx - cx) / 0.10, (ny - cy) / 0.28) - 1.0))
            bg = blend(bg, (246, 252, 255), ring)
            stem = smoothstep(0.018, 0.0, abs(nx - 0.12)) * smoothstep(0.25, 0.29, ny) * smoothstep(0.75, 0.71, ny)
            bg = blend(bg, (246, 252, 255), stem)
            pixels.extend(bg)
    write_png(path, width, height, pixels)


def main():
    for filename, size in {
        "Icon-20@2x.png": 40,
        "Icon-20@3x.png": 60,
        "Icon-29@2x.png": 58,
        "Icon-29@3x.png": 87,
        "Icon-40@2x.png": 80,
        "Icon-40@3x.png": 120,
        "Icon-60@2x.png": 120,
        "Icon-60@3x.png": 180,
        "Icon-1024.png": 1024,
    }.items():
        render_square(ICON_DIR / filename, size)

    render_logo(LOGO_DIR / "DaedalusLogo.png", 256, 96)
    render_logo(LOGO_DIR / "DaedalusLogo@2x.png", 512, 192)
    render_logo(LOGO_DIR / "DaedalusLogo@3x.png", 768, 288)


if __name__ == "__main__":
    main()
