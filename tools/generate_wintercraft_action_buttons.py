#!/usr/bin/env python3

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = ROOT / "textures" / "base" / "pack"
FONT_PATH = Path("/usr/share/fonts/truetype/ubuntu/Ubuntu-C.ttf")

BASE_IMAGES = {
    1: TEXTURE_DIR / "wintercraft_settings_button1.png",
    2: TEXTURE_DIR / "wintercraft_settings_button2.png",
}

LABELS = {
    "main_menu": "MAIN MENU",
    "delete": "DELETE",
    "select_mods": "SELECT MODS",
    "new": "NEW",
    "new_world": "NEW WORLD",
    "play_game": "PLAY GAME",
    "login": "LOGIN",
    "register": "REGISTER",
    "my_servers": "MY SERVERS",
    "create_server": "CREATE SERVER",
    "save": "SAVE",
    "use": "USE",
    "close": "CLOSE",
}

MIN_WIDTHS = {
    "main_menu": 205,
    "delete": 180,
    "select_mods": 230,
    "new": 165,
    "new_world": 210,
    "play_game": 220,
    "login": 170,
    "register": 195,
    "my_servers": 225,
    "create_server": 245,
    "save": 165,
    "use": 165,
    "close": 175,
}


def build_blank_button(base: Image.Image, width: int) -> Image.Image:
    left_cap = 14
    right_cap = 14
    strip_x = 10
    height = base.height

    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    result.alpha_composite(base.crop((0, 0, left_cap, height)), (0, 0))

    strip = base.crop((strip_x, 0, strip_x + 1, height))
    for x in range(left_cap, width - right_cap):
        result.alpha_composite(strip, (x, 0))

    result.alpha_composite(
        base.crop((base.width - right_cap, 0, base.width, height)),
        (width - right_cap, 0),
    )
    return result


def draw_label(image: Image.Image, label: str, font: ImageFont.FreeTypeFont) -> None:
    draw = ImageDraw.Draw(image)
    bbox = draw.textbbox((0, 0), label, font=font, stroke_width=2)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (image.width - text_w) // 2 - bbox[0]
    y = (image.height - text_h) // 2 - bbox[1] - 1

    fill = (245, 241, 236, 255)
    shadow = (110, 104, 98, 255)
    stroke = (72, 68, 65, 255)

    draw.text((x + 1, y + 2), label, font=font, fill=shadow, stroke_width=2, stroke_fill=stroke)
    draw.text((x, y), label, font=font, fill=fill, stroke_width=2, stroke_fill=stroke)


def main() -> None:
    font = ImageFont.truetype(str(FONT_PATH), 22)
    scratch = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    scratch_draw = ImageDraw.Draw(scratch)

    widths = {}
    for button_id, label in LABELS.items():
        bbox = scratch_draw.textbbox((0, 0), label, font=font, stroke_width=2)
        text_width = bbox[2] - bbox[0]
        widths[button_id] = max(MIN_WIDTHS[button_id], text_width + 38)

    for state, base_path in BASE_IMAGES.items():
        base = Image.open(base_path).convert("RGBA")
        for button_id, label in LABELS.items():
            image = build_blank_button(base, widths[button_id])
            draw_label(image, label, font)
            image.save(TEXTURE_DIR / f"wintercraft_btn_{button_id}_{state}.png")

    for button_id in sorted(widths):
        print(f"{button_id}: {widths[button_id]}/44")


if __name__ == "__main__":
    main()
