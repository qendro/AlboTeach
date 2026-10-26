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
                "options": dict(per_sheet=per_sheet, flip=flip, art_style="original", back_x_mm=offsets.get("x", 0), back_y_mm=offsets.get("y", 0))}

    def test_low_ink_maps_legacy_art_without_changing_input(self):
        payload = self.payload(1)
        payload["options"]["art_style"] = "outline"
        pdf = self.create(payload)
        self.assertIn("Lucide", pdf.metadata.subject)
        self.assertIn("line-apple", pdf.metadata.subject)
        self.assertNotIn("1f34e.svg", pdf.metadata.subject)
        self.assertEqual(payload["cards"][0]["image"], "apple")
        for page in pdf.pages:
            for operands, operator in ContentStream(page.get_contents(), pdf).operations:
                if operator in (b"rg", b"RG"):
                    self.assertEqual(operands[0], operands[1])
                    self.assertEqual(operands[1], operands[2])
        payload["cards"][0]["image"] = "rice"
        fallback = self.create(payload)
        self.assertFalse(any(op == b"Do" for _, op in ContentStream(fallback.pages[0].get_contents(), fallback).operations))
        payload["options"]["art_style"] = "invalid"
        with self.assertRaisesRegex(ValueError, "artwork"):
            self.create(payload)

    def test_color_is_default_for_starters_and_expansion_without_changing_saved_keys(self):
        payload = self.payload(2)
        del payload["options"]["art_style"]
        payload["cards"][1]["image"] = "line-carrot"
        pdf = self.create(payload)
        self.assertIn("Microsoft", pdf.metadata.subject)
        self.assertIn("color-apple", pdf.metadata.subject)
        self.assertIn("color-carrot", pdf.metadata.subject)
        self.assertIn("Copyright (c) Microsoft Corporation", pdf.metadata.subject)
        self.assertNotIn("line-carrot:", pdf.metadata.subject)
        self.assertEqual(payload["cards"][1]["image"], "line-carrot")
        for image_side in ("albanian", "english"):
            payload["options"]["image_side"] = image_side
            pdf = self.create(payload)
            for index, page in enumerate(pdf.pages):
                draws = sum(op == b"Do" for _, op in ContentStream(page.get_contents(), pdf).operations)
                self.assertEqual(draws, 2 if index == (0 if image_side == "albanian" else 1) else 0)

    def create(self, payload):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        output = Path(folder.name) / "cards.pdf"
        printing.render(payload, output)
        return PdfReader(output)

    def positions(self, page):
        positions = {}
        def visitor(text, cm, tm, font, size):
            text = text.strip()
            if text.startswith("AT-"):
                positions[text.strip()] = (tm[4], tm[5])
            elif text.startswith(("mollë ç ", "apple ")):
                key = int(text.strip().split()[-1])
                positions[key] = (tm[4] + printing.pdfmetrics.stringWidth(text.strip(), "CardsBold", size) / 2,
                                  tm[5] + size * 1.55)
        page.extract_text(visitor_text=visitor)
        return positions

    def test_duplex_pdf_positions_for_all_grids_flips_and_partial_sheets(self):
        for per_sheet, cols, rows in ((8, 2, 4), (10, 2, 5), (21, 3, 7)):
            for flip in ("long-edge", "short-edge"):
                with self.subTest(per_sheet=per_sheet, flip=flip):
                    payload = self.payload(per_sheet + 1, per_sheet, flip)
                    for card in payload["cards"]:
                        card["image"] = ""
                    pdf = self.create(payload)
                    self.assertEqual(len(pdf.pages), 4)
                    for page in pdf.pages:
                        self.assertEqual(tuple(page.mediabox), (0, 0, 612, 792))
                    for front, back in ((pdf.pages[0], pdf.pages[1]), (pdf.pages[2], pdf.pages[3])):
                        f, b = self.positions(front), self.positions(back)
                        self.assertEqual(len(f), per_sheet if front is pdf.pages[0] else 1)
                        self.assertEqual(f.keys(), b.keys())
                        for key, (x, y) in f.items():
                            if flip == "long-edge":
                                slot = (key - 1) % per_sheet
                                col = slot % cols
                                self.assertAlmostEqual(b[key][0] - x, (cols - 1 - 2 * col) * 612 / cols, places=3)
                                self.assertAlmostEqual(b[key][1], y, places=3)
                            else:
                                self.assertAlmostEqual(b[key][0], x, places=3)
                                self.assertAlmostEqual(b[key][1] + y, 792, places=3)
                    self.assertEqual(len(self.positions(pdf.pages[2])), 1)
                    self.assertIn("mollë ç 1", pdf.pages[0].extract_text())
                    self.assertNotIn("apple 1", pdf.pages[0].extract_text())
                    self.assertIn("apple 1", pdf.pages[1].extract_text())

    def test_offsets_only_move_backs(self):
        base = self.create(self.payload(1))
        shifted = self.create(self.payload(1, x=1, y=-2))
        self.assertEqual(self.positions(base.pages[0]), self.positions(shifted.pages[0]))
        first = self.positions(base.pages[1])[1]
        second = self.positions(shifted.pages[1])[1]
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

    def test_albanian_only_has_no_backs_and_keeps_pictures_and_cut_guides(self):
        for per_sheet in (8, 10, 21):
            with self.subTest(per_sheet=per_sheet):
                payload = self.payload(per_sheet + 1, per_sheet)
                payload["options"].update(sides="albanian", image_side="english", back_x_mm=3, back_y_mm=-2)
                for card in payload["cards"]:
                    card["english"] = "English must not print 🫠"
                pdf = self.create(payload)
                self.assertEqual(len(pdf.pages), 2)
                for page_number, page in enumerate(pdf.pages):
                    expected = payload["cards"][page_number * per_sheet:(page_number + 1) * per_sheet]
                    self.assertEqual([line.strip() for line in page.extract_text().splitlines()],
                                     [card["albanian"] for card in expected])
                    operations = ContentStream(page.get_contents(), pdf).operations
                    self.assertEqual(sum(op == b"Do" for _, op in operations), len(expected))
                    cols, rows = printing.grid_shape(per_sheet)
                    self.assertEqual(sum(op == b"l" for _, op in operations), cols + rows - 2)
                payload["options"]["sides"] = "invalid"
                with self.assertRaisesRegex(ValueError, "sides"):
                    self.create(payload)

    def test_pages_contain_only_vocabulary_larger_pictures_and_front_cut_guides(self):
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
                            expected = [card["albanian" if index == 0 else "english"] for card in payload["cards"]]
                            self.assertEqual([line.strip() for line in page.extract_text().splitlines()], expected)
                            operations = ContentStream(page.get_contents(), pdf).operations
                            image_sizes = [float(args[0]) for args, op in operations
                                           if op == b"cm" and float(args[0]) > 1]
                            if illustrated:
                                old_size = {8: 70, 10: 56.16, 21: 28}[per_sheet]
                                self.assertEqual(len(image_sizes), 2)
                                self.assertTrue(all(size > old_size * 1.4 for size in image_sizes))
                            starts = [tuple(round(float(v), 3) for v in args) for args, op in operations if op == b"m"]
                            ends = [tuple(round(float(v), 3) for v in args) for args, op in operations if op == b"l"]
                            cols, rows = printing.grid_shape(per_sheet)
                            guides = [(round(col * 612 / cols, 3), 0, round(col * 612 / cols, 3), 792)
                                      for col in range(1, cols)]
                            guides += [(0, round(row * 792 / rows, 3), 612, round(row * 792 / rows, 3))
                                       for row in range(1, rows)]
                            self.assertEqual([start + end for start, end in zip(starts, ends)], guides if index == 0 else [])
                        self.assertIn("CC BY 4.0", pdf.metadata.subject)
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
