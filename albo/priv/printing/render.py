"""Offline printable flashcards. Input is a validated webapp snapshot, never a database."""

import json
import math
from pathlib import Path
import sys

from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

ASSETS = Path(__file__).resolve().parent
INK = HexColor("#183e36")
PAGE_WIDTH, PAGE_HEIGHT = 612, 792


def register_fonts():
    for name, filename in [("Cards", "Vera.ttf"), ("CardsBold", "VeraBd.ttf")]:
        pdfmetrics.registerFont(TTFont(name, str(ASSETS / "fonts" / filename)))


def grid_shape(per_sheet):
    return {8: (2, 4), 10: (2, 5), 21: (3, 7)}[per_sheet]


def geometry(slot, per_sheet, side, flip):
    cols, rows = grid_shape(per_sheet)
    row, col = divmod(slot, cols)
    if side == "back":
        if flip == "long-edge":
            col = cols - 1 - col
        else:
            row = rows - 1 - row
    width, height = PAGE_WIDTH / cols, PAGE_HEIGHT / rows
    return col * width, PAGE_HEIGHT - (row + 1) * height, width, height


def text_layout(text, width, height, max_size=28):
    supported = pdfmetrics.getFont("CardsBold").face.charToGlyph
    if any(ord(ch) not in supported for ch in text if not ch.isspace()):
        raise ValueError("A selected card contains a character the print font cannot display. Edit that card before printing.")
    for size in range(max_size, 10, -1):
        lines = []
        current = ""
        # Wrap long words too, so any valid 160-character card remains printable.
        for word in text.split():
            trial = (current + " " + word).strip()
            if pdfmetrics.stringWidth(trial, "CardsBold", size) <= width:
                current = trial
                continue
            if current:
                lines.append(current)
            current = ""
            for char in word:
                if pdfmetrics.stringWidth(current + char, "CardsBold", size) > width:
                    lines.append(current)
                    current = ""
                current += char
        if current:
            lines.append(current)
        if lines and len(lines) * size * 1.22 <= height:
            return lines, size
    raise ValueError("A selected card has too much text to print legibly. Shorten its wording and try again.")


def centered(pdf, text, x, y, width, height, max_size=28):
    lines, size = text_layout(text, width, height, max_size)
    pdf.setFont("CardsBold", size)
    baseline = y + height / 2 + (len(lines) - 1) * size * 1.22 / 2 - size * 0.35
    for index, line in enumerate(lines):
        pdf.drawCentredString(x + width / 2, baseline - index * size * 1.22, line)


def face(pdf, card, box, side, images, calibration, image_side, ink=INK, offset=(0, 0)):
    x, y, width, height = box
    paper_y = y
    x += offset[0]
    y += offset[1]
    compact = height < 120
    text_padding = 18
    pdf.setFillColor(ink)
    word = card["albanian"] if side == "front" else card["english"]
    if calibration:
        padding, header, label_size = 18, 26, 5.5 if compact else 7
        pdf.setFont("Cards", label_size)
        pdf.drawString(x + padding, y + height - header, "SHQIP" if side == "front" else "ENGLISH")
        pdf.drawRightString(x + width - padding, y + height - header, f"AT-{card['id']:04d}")
        cx, cy = x + width / 2, y + height / 2
        pdf.setStrokeColor(ink)
        pdf.setLineWidth(0.5)
        cross, square = (9, 14) if compact else (12, 18)
        pdf.line(cx - cross, cy, cx + cross, cy)
        pdf.line(cx, cy - cross, cx, cy + cross)
        pdf.rect(cx - square, cy - square, square * 2, square * 2)
        centered(pdf, word, x + text_padding, cy + (21 if compact else 24), width - 2 * text_padding,
                 20 if compact else 30, 14 if compact else 20)
        pdf.setFont("Cards", 5.5 if compact else 7)
        pdf.drawCentredString(cx, cy - (26 if compact else 36),
                             "Match numbers and centers" if compact else "Match numbers and centers through the paper")
    else:
        picture_face = "front" if image_side == "albanian" else "back"
        image = images.get(card.get("image")) if side == picture_face else None
        padding = 8 if compact else 10
        gap = 6 if compact else 8
        max_size = 22 if compact else 28
        # Keep content inset from the paper edges, even though the cut grid fills the sheet.
        bottom_padding = max(padding, 18 - paper_y)
        top_padding = max(padding, 18 - (PAGE_HEIGHT - paper_y - height))
        available = height - bottom_padding - top_padding
        bottom = y + bottom_padding
        text_height = available
        if image:
            # Reserve enough room for the wording before expanding the illustration.
            lines, font_size = text_layout(word, width - 2 * text_padding, available * 0.4, max_size)
            text_height = len(lines) * font_size * 1.22
            size = min(width - 2 * text_padding, height * 0.65, available - text_height - gap)
            bottom += (available - size - gap - text_height) / 2
            image_bottom = bottom + text_height + gap
            pdf.drawImage(str(ASSETS / "images" / image["file"]), x + (width - size) / 2,
                          image_bottom, size, size, mask="auto")
        centered(pdf, word, x + text_padding, bottom, width - 2 * text_padding, text_height, max_size)


def render(payload, output):
    options = payload["options"]
    per_sheet, flip = options["per_sheet"], options["flip"]
    if per_sheet not in (8, 10, 21) or flip not in ("long-edge", "short-edge"):
        raise ValueError("Choose a valid card layout and duplex setting.")
    sides = options.get("sides", "both")
    if sides not in ("both", "albanian"):
        raise ValueError("Choose both sides or Albanian only.")
    image_side = options.get("image_side", "albanian")
    if image_side not in ("albanian", "english"):
        raise ValueError("Choose the Albanian or English side for pictures.")
    if sides == "albanian":
        image_side = "albanian"
    dx, dy = options["back_x_mm"], options["back_y_mm"]
    if any(not math.isfinite(v) or abs(v) > 5 for v in (dx, dy)):
        raise ValueError("Back offsets must be between -5 and 5 mm.")
    calibration = payload.get("calibration", False)
    cards = payload["cards"]
    if calibration:
        cards = [dict(id=n, revision=1, albanian=f"FRONT {n}", english=f"BACK {n}")
                 for n in range(1, per_sheet + 1)]
    if not 1 <= len(cards) <= 300:
        raise ValueError("Select between 1 and 300 cards.")
    register_fonts()
    cols, rows = grid_shape(per_sheet)
    images = {entry["key"]: entry for entry in json.loads((ASSETS / "images/credits.json").read_text())}
    art_style = options.get("art_style", "color")
    if art_style not in ("color", "outline", "original"):
        raise ValueError("Choose valid printer artwork.")
    ink = HexColor("#000000") if art_style != "original" else INK
    if art_style == "color":
        color_map = json.loads((ASSETS.parent / "collections/color-art/display-map.json").read_text())
        cards = [dict(card, image=color_map.get(card.get("image"), card.get("image"))) for card in cards]
    if art_style == "outline":
        outline_map = json.loads((ASSETS.parent / "collections/kosovo-200/print-outline-map.json").read_text())
        # Unknown/color-only artwork becomes text-only in low-ink mode. Saved cards stay intact.
        cards = [dict(card, image=(card.get("image") if str(card.get("image", "")).startswith("line-")
                                  else (str(card["image"]).replace("color-", "line-", 1)
                                        if str(card.get("image", "")).startswith("color-")
                                        else outline_map.get(card.get("image"), "")))) for card in cards]
    pdf = canvas.Canvas(str(output), pagesize=(PAGE_WIDTH, PAGE_HEIGHT), pageCompression=1)
    pdf.setTitle("AlboTeach / " + ("Printer calibration" if calibration else "Physical flashcards"))
    pdf.setAuthor("AlboTeach")
    used_images = {card.get("image") for card in cards} & images.keys()
    attribution = "\n".join(f"{key}: {images[key]['credit']} / {images[key]['license']} / {images[key]['source']} / {images[key]['changes']}"
                            for key in sorted(used_images))
    if any(key.startswith("line-") for key in used_images):
        attribution += "\n" + (ASSETS / "images/LICENSE-Lucide.txt").read_text()
        attribution += "\n" + (ASSETS / "images/LICENSE-AlboTeach-Outline.txt").read_text()
    if any(key.startswith("color-") for key in used_images):
        attribution += "\n" + (ASSETS / "images/LICENSE-Fluent-Emoji.txt").read_text()
        attribution += "\n" + (ASSETS / "images/LICENSE-AlboTeach-Color.txt").read_text()
    pdf.setSubject(attribution)
    for start in range(0, len(cards), per_sheet):
        for side in (("front", "back") if sides == "both" else ("front",)):
            for slot, card in enumerate(cards[start:start + per_sheet]):
                box = geometry(slot, per_sheet, side, flip)
                offset = (dx * 72 / 25.4, dy * 72 / 25.4) if side == "back" else (0, 0)
                face(pdf, card, box, side, images, calibration, image_side, ink, offset)
            if side == "front":
                pdf.setStrokeColor(HexColor("#bbbbbb") if art_style != "original" else HexColor("#bdc8b5"))
                pdf.setLineWidth(0.35)
                pdf.setDash(2, 3)
                # The paper edges finish the outer cards; only internal cuts are needed.
                for col in range(1, cols):
                    x = col * PAGE_WIDTH / cols
                    pdf.line(x, 0, x, PAGE_HEIGHT)
                for row in range(1, rows):
                    y = row * PAGE_HEIGHT / rows
                    pdf.line(0, y, PAGE_WIDTH, y)
                pdf.setDash()
            pdf.showPage()
    pdf.save()


if __name__ == "__main__":
    try:
        render(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")), sys.argv[2])
    except ValueError as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
