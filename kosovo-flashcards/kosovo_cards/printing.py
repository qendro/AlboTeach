"""Letter duplex PDF output and an offline visual review report."""

import base64
import hashlib
import html
import json
import mimetypes
import os
import tempfile
from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from .store import ASSETS
from .vendor.layout import calculate_layout, wrap_text_to_lines

INK = HexColor("#153C47")
TEAL = HexColor("#237F83")
MUTED = HexColor("#6D7E83")


def fonts():
    for name, file in [("Cards", "Vera.ttf"), ("CardsBold", "VeraBd.ttf")]:
        if name not in pdfmetrics.getRegisteredFontNames():
            pdfmetrics.registerFont(TTFont(name, str(ASSETS / "fonts" / file)))


def centered(c, text, x, y, width, height, max_size=28):
    font = "CardsBold"
    # Reject characters the bundled font cannot display, instead of printing tofu.
    supported = pdfmetrics.getFont(font).face.charToGlyph
    if any(ord(ch) not in supported for ch in text if not ch.isspace()):
        raise ValueError(f"Unsupported printable glyph in {text!r}")
    for size in range(max_size, 11, -1):
        lines = wrap_text_to_lines(text, width, font, size, c)
        if len(lines) * size * 1.22 <= height and all(
            c.stringWidth(line, font, size) <= width for line in lines
        ):
            c.setFont(font, size)
            baseline = y + height / 2 + (len(lines) - 1) * size * 1.22 / 2 - size * 0.35
            for i, line in enumerate(lines):
                c.drawCentredString(x + width / 2, baseline - i * size * 1.22, line)
            return
    raise ValueError(f"Text cannot fit at a readable size: {text!r}. Shorten the card.")


def card_face(c, card, g, side, image=None, dx=0, dy=0):
    x, y, w, h = g.x + dx, g.y + dy, g.width, g.height
    c.saveState()
    c.setFillColor(TEAL if side == "front" else MUTED)
    c.setFont("Cards", 7)
    c.drawString(x + 15, y + h - 19, "SHQIP" if side == "front" else "ENGLISH")
    c.drawRightString(x + w - 15, y + h - 19, f"KC-{card['id']:04d}")
    c.setFillColor(INK)
    if card.get("calibration"):
        c.setStrokeColor(TEAL)
        c.setLineWidth(0.5)
        cx, cy = x + w / 2, y + h / 2
        c.line(cx - 12, cy, cx + 12, cy)
        c.line(cx, cy - 12, cx, cy + 12)
        c.rect(cx - 18, cy - 18, 36, 36, stroke=1, fill=0)
        centered(
            c,
            card["albanian"] if side == "front" else card["english"],
            x + 18,
            cy + 25,
            w - 36,
            32,
            20,
        )
        c.setFont("Cards", 7)
        c.drawCentredString(
            cx, cy - 35, "Centers and squares should align through the paper"
        )
    elif side == "front" and image:
        size = min(76, h * 0.43)
        c.drawImage(
            image["resolved_path"],
            x + (w - size) / 2,
            y + h - 34 - size,
            width=size,
            height=size,
            mask="auto",
            preserveAspectRatio=True,
            anchor="c",
        )
        text_top = y + h - 40 - size
        centered(c, card["albanian"], x + 16, y + 25, w - 32, text_top - y - 25, 28)
    else:
        centered(
            c,
            card["albanian"] if side == "front" else card["english"],
            x + 18,
            y + 25,
            w - 36,
            h - 62,
            28,
        )
    c.setFont("Cards", 6.5)
    c.setFillColor(MUTED)
    if card["status"] != "approved":
        c.drawCentredString(x + w / 2, y + 12, "DRAFT - TUTOR REVIEW REQUIRED")
    c.restoreState()


def page_marks(c, layout, front, sheet, flip, dx, dy, credits, draft):
    # Cut only using front marks. Back grid omitted to avoid confusing feed drift.
    if front:
        c.setLineWidth(0.35)
        c.setStrokeColor(HexColor("#AFBDC1"))
        c.setDash(2, 3)
        for col in range(layout.cols + 1):
            x = layout.margin + col * layout.card_width
            c.line(x, layout.margin, x, layout.page_height - layout.margin)
        for row in range(layout.rows + 1):
            y = layout.margin + row * layout.card_height
            c.line(layout.margin, y, layout.page_width - layout.margin, y)
        c.setDash()
    c.setFillColor(MUTED)
    c.setFont("Cards", 6.5)
    label = f"Sheet {sheet} / {'FRONT' if front else 'BACK'} / {flip} / 100% scale"
    if draft:
        label += " / DRAFT"
    c.drawString(36, 778, label)
    if not front and (dx or dy):
        c.drawRightString(576, 778, f"Back offset: {dx:.1f}, {dy:.1f} pt")
    # Credits always remain attached to the physical printed sheet.
    credit = (
        "Art: Twemoji / Twitter & contributors / CC BY 4.0 / github.com/jdecked/twemoji"
    )
    c.drawCentredString(
        306,
        20,
        (
            credit
            if any("Twemoji" in a["credit"] for a in credits)
            else "Kosovo Albanian / local flashcard collection"
        ),
    )


def render_pdf(
    store,
    cards,
    output,
    *,
    per_sheet=8,
    flip="long-edge",
    allow_proposed=False,
    back_x_mm=0,
    back_y_mm=0,
):
    if not cards:
        raise ValueError("No cards selected")
    if flip not in ("long-edge", "short-edge"):
        raise ValueError("Unknown flip")
    if any(c["status"] == "rejected" for c in cards):
        raise ValueError("Rejected cards cannot be printed")
    if any(c["status"] != "approved" for c in cards) and not allow_proposed:
        raise ValueError(
            "Selection contains proposed cards. Review them first or explicitly use --allow-proposed for a draft."
        )
    if abs(back_x_mm) > 5 or abs(back_y_mm) > 5:
        raise ValueError("Back offsets must be within +/-5 mm")
    fonts()
    layout = calculate_layout(per_sheet)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    images = {c["id"]: store.image(c["image"]) for c in cards}
    credits = [a for a in images.values() if a]
    dx, dy = back_x_mm * 72 / 25.4, back_y_mm * 72 / 25.4
    # Fully render to a temporary file, so layout errors do not destroy an old PDF.
    fd, tmp = tempfile.mkstemp(suffix=".pdf", dir=output.parent)
    os.close(fd)
    try:
        pdf = canvas.Canvas(tmp, pagesize=(612, 792), pageCompression=1)
        pdf.setTitle(
            "Kosovo Albanian Flashcards" + (" - DRAFT" if allow_proposed else "")
        )
        pdf.setAuthor("Kosovo Cards")
        credit_text = "\n".join(
            sorted(
                {
                    f"{a['key']}: {a['credit']} | {a['license']} | {a['source']}"
                    for a in credits
                }
            )
        )
        pdf.setSubject(
            "Illustration credits: " + (credit_text or "No external illustrations.")
        )
        placements = []
        for start in range(0, len(cards), per_sheet):
            chunk = cards[start : start + per_sheet]
            sheet = start // per_sheet + 1
            for side in ("front", "back"):
                for slot, card in enumerate(chunk):
                    g = layout.geometry(slot, side, flip)
                    card_face(
                        pdf,
                        card,
                        g,
                        side,
                        images[card["id"]],
                        dx if side == "back" else 0,
                        dy if side == "back" else 0,
                    )
                    placements.append(
                        {
                            "id": card["id"],
                            "revision": card["revision"],
                            "sheet": sheet,
                            "side": side,
                            "x": g.x + (dx if side == "back" else 0),
                            "y": g.y + (dy if side == "back" else 0),
                            "width": g.width,
                            "height": g.height,
                        }
                    )
                page_marks(
                    pdf,
                    layout,
                    side == "front",
                    sheet,
                    flip,
                    dx,
                    dy,
                    credits,
                    any(c["status"] != "approved" for c in chunk),
                )
                pdf.showPage()
        pdf.save()
        os.replace(tmp, output)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    snapshot = {
        "schema_version": 1,
        "paper": "US Letter",
        "scale_percent": 100,
        "flip": flip,
        "cards_per_sheet": per_sheet,
        "back_offset_mm": [back_x_mm, back_y_mm],
        "cards": cards,
        "placements": placements,
        "images": [
            {k: v for k, v in a.items() if k != "resolved_path"}
            | {
                "sha256": hashlib.sha256(
                    Path(a["resolved_path"]).read_bytes()
                ).hexdigest()
            }
            for a in credits
        ],
        "pdf_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    }
    output.with_suffix(".manifest.json").write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    output.with_suffix(".credits.txt").write_text(
        "Illustration credits for "
        + output.name
        + "\n\n"
        + (credit_text or "No external illustrations.")
        + "\n\nBundled Twemoji: original SVGs converted to PNG; artwork unchanged.\nKeep this file with the PDF when sharing custom artwork credits.\n",
        encoding="utf-8",
    )
    return {
        "pdf": str(output),
        "manifest": str(output.with_suffix(".manifest.json")),
        "cards": len(cards),
        "pages": 2 * ((len(cards) + per_sheet - 1) // per_sheet),
    }


def calibration(output, flip="long-edge", back_x_mm=0, back_y_mm=0):
    class Fixture:
        def image(self, key):
            return None

    cards = [
        {
            "id": i + 1,
            "revision": 1,
            "albanian": f"FRONT {i+1}",
            "english": f"BACK {i+1}",
            "status": "approved",
            "image": "",
            "calibration": True,
            "notes": "Calibration fixture; not vocabulary",
        }
        for i in range(8)
    ]
    result = render_pdf(
        Fixture(), cards, output, flip=flip, back_x_mm=back_x_mm, back_y_mm=back_y_mm
    )
    return result


def review_html(store, cards, output):
    esc = lambda s: html.escape(str(s), quote=True)
    blocks = []
    credits = {}
    for card in cards:
        image = store.image(card["image"])
        art = ""
        if image:
            path = Path(image["resolved_path"])
            uri = (
                "data:"
                + mimetypes.guess_type(path.name)[0]
                + ";base64,"
                + base64.b64encode(path.read_bytes()).decode()
            )
            art = f'<img alt="Illustration for {esc(card["english"])}" src="{uri}">'
            credits[image["key"]] = image
        blocks.append(
            f"""<article><div class="meta">KC-{card['id']:04d} · revision {card['revision']} · {esc(card['status'])}</div>
<div class="face">{art}<h2 lang="sq">{esc(card['albanian'])}</h2><p>{esc(card['english'])}</p></div>
<div class="notes"><b>{esc(card['category'])}</b> · {esc(card['part_of_speech'])}<br>{esc(card['notes'])}<br>
Source: {esc(card['source'] or 'unspecified')}<br>Reviewer: {esc(card['reviewer'] or 'Not yet reviewed')}</div></article>"""
        )
    attribution = "".join(
        f'<li>{esc(a["key"])}: {esc(a["credit"])}; {esc(a["license"])}; {esc(a["source"])}</li>'
        for a in credits.values()
    )
    doc = (
        """<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kosovo Albanian · Vocabulary review</title><style>
*{box-sizing:border-box}body{margin:0;background:#f5f7f6;color:#153c47;font-family:system-ui,sans-serif}
main{max-width:1100px;margin:auto;padding:36px 24px}h1{font-size:32px;margin-bottom:8px}.intro{max-width:740px;line-height:1.6;color:#526970}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(255px,1fr));gap:18px;margin:28px 0}
article{background:white;border:1px solid #dbe3e3;border-radius:12px;overflow:hidden}.meta{padding:12px 16px;background:#eaf3f2;font-size:12px}
.face{min-height:210px;text-align:center;padding:20px 10px}.face img{width:85px;height:85px;object-fit:contain}h2{font-size:28px;margin:10px 0}p{margin:8px 0}
.notes{border-top:1px solid #edf0ef;padding:14px;font-size:12px;color:#526970;line-height:1.7;overflow-wrap:anywhere}li{font-size:11px;overflow-wrap:anywhere}footer{margin-top:36px}
</style><main><p>KOSOVO ALBANIAN / REVIEW</p><h1>Words for everyday conversation</h1>
<p class="intro">Review spelling, meaning, family dialect and illustration together. Proposed vocabulary is an AI draft, not verified Kosovo Albanian. Approvals are recorded through Codex or the command line; this is a static, offline report.</p><div class="grid">"""
        + "".join(blocks)
        + f"</div><footer><h3>Illustration credits</h3><ul>{attribution}</ul></footer></main></html>"
    )
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(doc, encoding="utf-8")
    return {"html": str(output), "cards": len(cards)}
