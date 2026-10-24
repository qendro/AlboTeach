"""Check actual PDF text coordinates, pairing, Unicode, and incomplete sheets."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

from pypdf import PdfReader
from pypdf.generic import ContentStream

spec = importlib.util.spec_from_file_location("printing", Path(__file__).resolve().parents[2] / "priv/printing/render.py")
printing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(printing)


class PrintingTest(unittest.TestCase):
    def payload(self, count=9, per_sheet=8, flip="long-edge", **offsets):
        return {"cards": [dict(id=i, revision=2, albanian=f"mollë ç {i}", english=f"apple {i}", image="apple")
                          for i in range(1, count + 1)],
                "options": dict(per_sheet=per_sheet, flip=flip, back_x_mm=offsets.get("x", 0), back_y_mm=offsets.get("y", 0))}

    def create(self, payload):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        output = Path(folder.name) / "cards.pdf"
        printing.render(payload, output)
        return PdfReader(output)

    def positions(self, page):
        positions = {}
        def visitor(text, cm, tm, font, size):
            if text.startswith("AT-"):
                positions[text.strip()] = (tm[4], tm[5])
        page.extract_text(visitor_text=visitor)
        return positions

    def test_duplex_pdf_positions_for_all_grids_flips_and_partial_sheets(self):
        for per_sheet, cols, rows in ((8, 2, 4), (10, 2, 5), (21, 3, 7)):
            for flip in ("long-edge", "short-edge"):
                with self.subTest(per_sheet=per_sheet, flip=flip):
                    pdf = self.create(self.payload(per_sheet + 1, per_sheet, flip))
                    self.assertEqual(len(pdf.pages), 4)
                    for page in pdf.pages:
                        self.assertEqual(tuple(page.mediabox), (0, 0, 612, 792))
                    for front, back in ((pdf.pages[0], pdf.pages[1]), (pdf.pages[2], pdf.pages[3])):
                        f, b = self.positions(front), self.positions(back)
                        self.assertEqual(f.keys(), b.keys())
                        for key, (x, y) in f.items():
                            if flip == "long-edge":
                                slot = (int(key[3:]) - 1) % per_sheet
                                col = slot % cols
                                self.assertAlmostEqual(b[key][0] - x, (cols - 1 - 2 * col) * 540 / cols)
                                self.assertAlmostEqual(b[key][1], y)
                            else:
                                self.assertAlmostEqual(b[key][0], x)
                                # Compact labels use 14pt padding + 6.6pt leading; others 20 + 8.4.
                                offset = 20.6 if per_sheet == 21 else 28.4
                                self.assertAlmostEqual(b[key][1] + y, 792 + 720 / rows - 2 * offset, places=3)
                    self.assertEqual(len(self.positions(pdf.pages[2])), 1)
                    self.assertIn("mollë ç 1", pdf.pages[0].extract_text())
                    self.assertNotIn("apple 1", pdf.pages[0].extract_text())
                    self.assertIn("apple 1", pdf.pages[1].extract_text())
                    self.assertIn("CC BY 4.0", pdf.pages[0].extract_text())
                    self.assertIn("1f34e.svg", pdf.metadata.subject)

    def test_offsets_only_move_backs(self):
        base = self.create(self.payload(1))
        shifted = self.create(self.payload(1, x=1, y=-2))
        self.assertEqual(self.positions(base.pages[0]), self.positions(shifted.pages[0]))
        first = self.positions(base.pages[1])["AT-0001"]
        second = self.positions(shifted.pages[1])["AT-0001"]
        self.assertAlmostEqual(second[0] - first[0], 72 / 25.4, places=3)
        self.assertAlmostEqual(second[1] - first[1], -144 / 25.4, places=3)

    def test_calibration_matches_layout_and_has_no_vocabulary(self):
        for per_sheet in (10, 21):
            payload = self.payload(0, per_sheet, "short-edge")
            payload["calibration"] = True
            pdf = self.create(payload)
            self.assertEqual(len(pdf.pages), 2)
            self.assertEqual(len(self.positions(pdf.pages[0])), per_sheet)
            self.assertIn(f"FRONT {per_sheet}", pdf.pages[0].extract_text())
            self.assertIn(f"BACK {per_sheet}", pdf.pages[1].extract_text())

    def test_three_by_seven_has_three_columns_seven_rows_and_compact_offsets(self):
        base = self.create(self.payload(21, 21))
        self.assertEqual(len(base.pages), 2)
        fronts = self.positions(base.pages[0])
        self.assertEqual(len({round(x, 3) for x, y in fronts.values()}), 3)
        self.assertEqual(len({round(y, 3) for x, y in fronts.values()}), 7)
        shifted = self.create(self.payload(21, 21, x=0.5, y=-0.5))
        self.assertEqual(fronts, self.positions(shifted.pages[0]))
        for key, (x, y) in self.positions(base.pages[1]).items():
            moved = self.positions(shifted.pages[1])[key]
            self.assertAlmostEqual(moved[0] - x, 36 / 25.4, places=3)
            self.assertAlmostEqual(moved[1] - y, -36 / 25.4, places=3)

    def test_invalid_input_and_unsupported_glyphs_fail_explicitly(self):
        for count in (0, 301):
            with self.assertRaises(ValueError):
                self.create(self.payload(count))
        with self.assertRaises(ValueError):
            self.create(self.payload(x=float("nan")))
        payload = self.payload(1)
        payload["cards"][0]["albanian"] = "unsupported 🫠"
        with self.assertRaisesRegex(ValueError, "character"):
            self.create(payload)

    def test_pictures_appear_only_on_chosen_language_and_revision_footer_is_removed(self):
        for per_sheet in (8, 10, 21):
            for flip in ("long-edge", "short-edge"):
                for image_side in ("albanian", "english"):
                    with self.subTest(per_sheet=per_sheet, flip=flip, image_side=image_side):
                        payload = self.payload(3, per_sheet, flip)
                        payload["options"]["image_side"] = image_side
                        payload["cards"][1]["image"] = ""
                        pdf = self.create(payload)
                        for index, page in enumerate(pdf.pages):
                            draws = sum(operator == b"Do" for operands, operator in ContentStream(page.get_contents(), pdf).operations)
                            illustrated = index == (0 if image_side == "albanian" else 1)
                            self.assertEqual(draws, 2 if illustrated else 0)
                            self.assertNotIn("AlboTeach / revision", page.extract_text())
                            self.assertIn("CC BY 4.0", page.extract_text())
                        self.assertIn("mollë ç 1", pdf.pages[0].extract_text())
                        self.assertIn("apple 1", pdf.pages[1].extract_text())
        default = self.create(self.payload(1))
        self.assertEqual(sum(op == b"Do" for _, op in ContentStream(default.pages[0].get_contents(), default).operations), 1)
        invalid = self.payload(1)
        invalid["options"]["image_side"] = "both"
        with self.assertRaisesRegex(ValueError, "side"):
            self.create(invalid)


if __name__ == "__main__":
    unittest.main()
