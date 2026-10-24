"""Adapted from martin-maly/flashcards src/layout.py and src/generator.py.
MIT; original copyright and license in LICENSE-flashcards.
Changes: Letter-only 8/10-card grids, point units, duplex slot mapping,
explicit horizontal bounds checking. No upstream runtime dependency.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class CardGeometry:
    x: float
    y: float
    width: float
    height: float


@dataclass(frozen=True)
class PageLayout:
    page_width: float = 612.0
    page_height: float = 792.0
    rows: int = 4
    cols: int = 2
    margin: float = 36.0

    @property
    def card_width(self):
        return (self.page_width - 2 * self.margin) / self.cols

    @property
    def card_height(self):
        return (self.page_height - 2 * self.margin) / self.rows

    def get_card_geometry(self, row, col):
        return CardGeometry(
            x=self.margin + col * self.card_width,
            y=self.page_height - self.margin - (row + 1) * self.card_height,
            width=self.card_width,
            height=self.card_height,
        )

    def geometry(self, slot, side="front", flip="long-edge"):
        row, col = divmod(slot, self.cols)
        if side == "back":
            if flip == "long-edge":
                col = self.cols - 1 - col
            elif flip == "short-edge":
                row = self.rows - 1 - row
            else:
                raise ValueError("Unknown duplex flip")
        return self.get_card_geometry(row, col)


def calculate_layout(cards_per_sheet=8):
    if cards_per_sheet not in (8, 10):
        raise ValueError("Choose 8 or 10 cards per sheet")
    return PageLayout(rows=cards_per_sheet // 2)


def wrap_text_to_lines(text, width, font_family, font_size, canvas_obj):
    """Upstream word-wrapping algorithm; oversized words are checked by caller."""
    words, lines, current_line = text.split(), [], []
    for word in words:
        test_line = " ".join(current_line + [word])
        if canvas_obj.stringWidth(test_line, font_family, font_size) <= width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(" ".join(current_line))
                current_line = [word]
            else:
                lines.append(word)
    if current_line:
        lines.append(" ".join(current_line))
    return lines
