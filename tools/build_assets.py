#!/usr/bin/env python3
# 从 APK 提取的图标生成 iOS Assets.xcassets
# 用法: python build_assets.py <apk_res_dir> <ios_project_dir>

import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

SRC = sys.argv[1] if len(sys.argv) > 1 else "res"
DST = sys.argv[2] if len(sys.argv) > 2 else "../ios/FastCode"

FONT_CANDIDATES = [
    "C:/Windows/Fonts/msyhbd.ttc",
    "C:/Windows/Fonts/msyh.ttc",
    "C:/Windows/Fonts/simhei.ttf",
    "C:/Windows/Fonts/simsun.ttc",
]

# 三套图标配色，直接来自 APK 采样
ICON_SETS = {
    "AppIcon":         ("#E0F7FA", "#00796B"),
    "AppIcon-deep":    ("#E3F2FD", "#1565C0"),
    "AppIcon-plain":   ("#1E1E1E", "#4DD0E1"),
}


def load_font(size):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_icon(bg_hex, fg_hex, path):
    """1024x1024，铺满底色 + 居中「取」字 + 下划线，字形比例照 APK 原图量出来的"""
    size = 1024
    im = Image.new("RGB", (size, size), bg_hex)
    d = ImageDraw.Draw(im)

    ch = "取"
    # 原图 192px 实测：字宽 54.2%、字顶 24.5%、下划线 76.6% 起、宽 36.5%、高 3.1%
    target_w = int(size * 0.542)
    font_size = 100
    best = None
    for fs in range(200, 900, 2):
        f = load_font(fs)
        box = d.textbbox((0, 0), ch, font=f)
        w = box[2] - box[0]
        if best is None or abs(w - target_w) < abs(best[2] - target_w):
            best = (box, fs, w)
    box, fs, w = best
    f = load_font(fs)

    x = (size - w) // 2 - box[0]
    y = int(size * 0.245) - box[1]
    d.text((x, y), ch, font=f, fill=fg_hex)

    bar_h = max(2, int(size * 0.031))
    bar_w = int(size * 0.365)
    bar_x = (size - bar_w) // 2
    bar_y = int(size * 0.766)
    d.rounded_rectangle(
        [bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
        radius=bar_h // 2,
        fill=fg_hex,
    )
    im.save(path, "PNG")


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fp:
        json.dump(obj, fp, indent=2, ensure_ascii=False)


def make_appicons(assets_dir):
    for name, (bg, fg) in ICON_SETS.items():
        d = os.path.join(assets_dir, f"{name}.appiconset")
        os.makedirs(d, exist_ok=True)
        draw_icon(bg, fg, os.path.join(d, "icon-1024.png"))
        write_json(os.path.join(d, "Contents.json"), {
            "images": [
                {"filename": "icon-1024.png", "idiom": "universal",
                 "platform": "ios", "size": "1024x1024"}
            ],
            "info": {"author": "xcode", "version": 1}
        })
        print(f"  AppIcon {name}")


def make_imageset(assets_dir, name, src_png):
    d = os.path.join(assets_dir, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    im = Image.open(src_png).convert("RGBA")
    im.save(os.path.join(d, f"{name}.png"), "PNG")
    write_json(os.path.join(d, "Contents.json"), {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1}
    })
    print(f"  imageset {name}  {im.size}")


def main():
    app_assets = os.path.join(DST, "FastCode", "Resources", "Assets.xcassets")
    widget_assets = os.path.join(DST, "FastCodeWidget", "Assets.xcassets")

    for base in (app_assets, widget_assets):
        write_json(os.path.join(base, "Contents.json"),
                   {"info": {"author": "xcode", "version": 1}})

    print("[1] AppIcon")
    make_appicons(app_assets)

    platforms = ["taobao", "pinduoduo", "jd", "douyin", "kuaishou", "dewu"]
    print("[2] 平台图标 -> App")
    for p in platforms:
        make_imageset(app_assets, f"ic_{p}", f"{SRC}/drawable-xxxhdpi/ic_{p}.png")

    print("[3] 平台图标 -> Widget")
    for p in platforms:
        make_imageset(widget_assets, f"ic_{p}", f"{SRC}/drawable-xxxhdpi/ic_{p}.png")

    print("[4] 应用图标预览")
    for src_name, dst_name in [
        ("ic_launcher", "ic_launcher"),
        ("ic_launcher_blue", "ic_launcher_blue"),
        ("ic_launcher_dark", "ic_launcher_dark"),
    ]:
        make_imageset(app_assets, dst_name, f"{SRC}/mipmap-xxxhdpi/{src_name}.png")

    # Widget 也要用到 AppIcon 里的 launcher 预览
    print("[5] 完成")


if __name__ == "__main__":
    main()
