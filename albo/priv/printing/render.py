"""Offline duplex flashcards. Input is a validated webapp snapshot, never a database."""

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
MUTED = HexColor("#71806d")


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
    width, height = 540 / cols, 720 / rows
    return 36 + col * width, 756 - (row + 1) * height, width, height


def centered(pdf, text, x, y, width, height, max_size=28):
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
            pdf.setFont("CardsBold", size)
            baseline = y + height / 2 + (len(lines) - 1) * size * 1.22 / 2 - size * 0.35
            for index, line in enumerate(lines):
                pdf.drawCentredString(x + width / 2, baseline - index * size * 1.22, line)
            return
    raise ValueError("A selected card has too much text to print legibly. Shorten its wording and try again.")


def face(pdf, card, box, side, images, calibration, image_side):
    x, y, width, height = box
    compact = height < 120
    padding, header, label_size = (10, 14, 5.5) if compact else (16, 20, 7)
    text_padding = 10 if compact else 18
    pdf.setFillColor(MUTED)
    pdf.setFont("Cards", label_size)
    pdf.drawString(x + padding, y + height - header, "SHQIP" if side == "front" else "ENGLISH")
    pdf.drawRightString(x + width - padding, y + height - header, f"AT-{card['id']:04d}")
    pdf.setFillColor(INK)
    word = card["albanian"] if side == "front" else card["english"]
    if calibration:
        cx, cy = x + width / 2, y + height / 2
        pdf.setStrokeColor(INK)
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
        bottom = 18 if compact else 24
        text_height = height - (40 if compact else 65)
        if image:
            size = 28 if compact else min(70, height * 0.39)
            image_bottom = y + height - (23 if compact else 30) - size
            pdf.drawImage(str(ASSETS / "images" / image["file"]), x + (width - size) / 2,
                          image_bottom, size, size, mask="auto")
            text_height = image_bottom - y - bottom - (5 if compact else 6)
        centered(pdf, word, x + text_padding, y + bottom, width - 2 * text_padding, text_height, 22 if compact else 28)


def render(payload, output):
    options = payload["options"]
    per_sheet, flip = options["per_sheet"], options["flip"]
    if per_sheet not in (8, 10, 21) or flip not in ("long-edge", "short-edge"):
        raise ValueError("Choose a valid card layout and duplex setting.")
    image_side = options.get("image_side", "albanian")
    if image_side not in ("albanian", "english"):
        raise ValueError("Choose the Albanian or English side for pictures.")
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
    pdf = canvas.Canvas(str(output), pagesize=(612, 792), pageCompression=1)
    pdf.setTitle("AlboTeach / " + ("Printer calibration" if calibration else "Physical flashcards"))
    pdf.setAuthor("AlboTeach")
    used_images = {card.get("image") for card in cards} & images.keys()
    pdf.setSubject("\n".join(f"{key}: {images[key]['credit']} / {images[key]['license']} / {images[key]['source']} / {images[key]['changes']}"
                            for key in sorted(used_images)))
    for start in range(0, len(cards), per_sheet):
        sheet = start // per_sheet + 1
        for side in ("front", "back"):
            for slot, card in enumerate(cards[start:start + per_sheet]):
                x, y, width, height = geometry(slot, per_sheet, side, flip)
                if side == "back":
                    x += dx * 72 / 25.4
                    y += dy * 72 / 25.4
                face(pdf, card, (x, y, width, height), side, images, calibration, image_side)
            if side == "front":
                pdf.setStrokeColor(HexColor("#bdc8b5"))
                pdf.setLineWidth(0.35)
                pdf.setDash(2, 3)
                for col in range(cols + 1):
                    x = 36 + col * 540 / cols
                    pdf.line(x, 36, x, 756)
                for row in range(rows + 1):
                    y = 36 + row * 720 / rows
                    pdf.line(36, y, 576, y)
                pdf.setDash()
            pdf.setFillColor(MUTED)
            pdf.setFont("Cards", 6.5)
            pdf.drawString(36, 776, f"AlboTeach / Sheet {sheet} / {side.upper()} / {flip} / Actual size 100%")
            pdf.drawRightString(576, 26, f"Back offset: X {dx:g}, Y {dy:g} mm")
            pdf.drawString(36, 26, "US Letter / Cut along front guides")
            if used_images:
                pdf.drawCentredString(306, 14, "Art: Twemoji / Twitter & contributors / CC BY 4.0 / github.com/jdecked/twemoji (SVG to PNG)")
            pdf.showPage()
    pdf.save()


if __name__ == "__main__":
    try:
        render(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")), sys.argv[2])
    except ValueError as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
