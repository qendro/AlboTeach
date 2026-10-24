"""Data preservation and duplex correspondence regression tests."""

import json
import tempfile
import unittest
from pathlib import Path
from pypdf import PdfReader
from kosovo_cards.store import Collection, FIELDS
from kosovo_cards.cli import apply_review
from kosovo_cards.printing import render_pdf, review_html


def draft(n=1, **kw):
    return {
        "concept": f"fixture.{n}",
        "albanian": f"Fjala {n}",
        "english": f"Word {n}",
        "category": "software fixture",
        **kw,
    }


class Workflow(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.s = Collection(self.root / "data/cards.sqlite")

    def tearDown(self):
        self.s.close()
        self.tmp.cleanup()

    def seed(self, n=1):
        return self.s.import_batch([draft(i + 1) for i in range(n)], "fixture")

    def review_document(self):
        return {
            "schema_version": 1,
            "cards": [
                {
                    **{k: c[k] for k in ("id", "revision", *FIELDS)},
                    "decision": "approved",
                }
                for c in self.s.cards()
            ],
        }

    def test_import_duplicates_preserve_corrections(self):
        self.seed()
        self.s.review([1], "approved", "Software fixture, not linguistic review")
        self.s.update(1, {"albanian": "Fjalë e re"}, 1)
        self.assertEqual(self.s.card(1)["status"], "proposed")
        result = self.s.import_batch(
            [draft(1), draft(2, albanian="Fjala 1")], "regeneration"
        )
        self.assertEqual(result["added"], [])
        self.assertEqual(self.s.card(1)["albanian"], "Fjalë e re")
        self.assertTrue(self.s.brief(5, "food")["excluded"])
        self.assertEqual(
            self.s.conn.execute("SELECT count(*) FROM history").fetchone()[0], 3
        )
        with self.assertRaises(ValueError):
            self.s.update(1, {"english": "changed"}, 1)

    def test_unicode_case_spacing_punctuation_duplicates(self):
        self.s.import_batch([draft(albanian="Çka?", english="What?")], "first")
        result = self.s.import_batch(
            [draft(2, albanian=" C\u0327KA! ", english="Something else")], "second"
        )
        self.assertEqual(result["added"], [])

    def test_failed_import_is_atomic(self):
        with self.assertRaises(ValueError):
            self.s.import_batch([draft(1), draft(2, image="missing")], "broken")
        self.assertEqual(self.s.cards(), [])
        self.assertIsNone(
            self.s.conn.execute("SELECT 1 FROM batches WHERE name='broken'").fetchone()
        )

    def test_selection_combines_ids_batch_status_and_limit(self):
        self.seed(3)
        self.s.review([1, 3], "approved", "Software fixture")
        cards = self.s.cards(batch="fixture", ids=[3, 2, 1], status="approved", limit=1)
        self.assertEqual([c["id"] for c in cards], [3])

    def test_review_approval_edits_and_stale_guard(self):
        self.seed(2)
        doc = self.review_document()
        doc["cards"][0]["albanian"] = "Fjalë"
        apply_review(self.s, doc, "Software fixture, not linguistic review")
        self.assertEqual(self.s.card(1)["status"], "approved")
        self.assertEqual(self.s.card(1)["revision"], 2)
        with self.assertRaises(ValueError):
            apply_review(self.s, doc, "fixture")

    def test_review_collision_rolls_back_all(self):
        self.seed(2)
        doc = self.review_document()
        doc["cards"][1]["albanian"] = doc["cards"][0]["albanian"]
        with self.assertRaises(ValueError):
            apply_review(self.s, doc, "fixture")
        self.assertTrue(all(c["status"] == "proposed" for c in self.s.cards()))

    def test_backup_persists_collection(self):
        self.seed(2)
        apply_review(self.s, self.review_document(), "Software fixture")
        self.s.backup(self.root / "backup")
        s = Collection(self.root / "backup/cards.sqlite")
        try:
            self.assertEqual(s.cards(), self.s.cards())
        finally:
            s.close()

    def test_managed_image_replacement_and_backup(self):
        from PIL import Image

        path = self.root / "art.png"
        Image.new("RGB", (40, 40), "green").save(path)
        self.seed()
        self.s.review([1], "approved", "fixture")
        self.s.add_image("new-art", path, "Fixture artist", "CC0", "Own fixture")
        self.s.update(1, {"image": "new-art"}, 1)
        path.unlink()
        self.assertEqual(self.s.card(1)["status"], "proposed")
        self.s.backup(self.root / "backup")
        s = Collection(self.root / "backup/cards.sqlite")
        try:
            self.assertTrue(Path(s.image("new-art")["resolved_path"]).exists())
        finally:
            s.close()

    def test_draft_and_rejected_print_guards(self):
        self.seed()
        with self.assertRaises(ValueError):
            render_pdf(self.s, self.s.cards(), self.root / "fail.pdf")
        self.s.review([1], "rejected", "fixture")
        with self.assertRaises(ValueError):
            render_pdf(
                self.s, self.s.cards(), self.root / "fail.pdf", allow_proposed=True
            )

    def test_duplex_pdf_locations_for_both_flips_grids_and_partial_sheet(self):
        self.seed(19)
        apply_review(self.s, self.review_document(), "Software fixture")
        for grid in (8, 10):
            for flip in ("long-edge", "short-edge"):
                path = self.root / f"{grid}-{flip}.pdf"
                render_pdf(self.s, self.s.cards(), path, per_sheet=grid, flip=flip)
                pdf = PdfReader(path)
                self.assertEqual(len(pdf.pages), 2 * ((19 + grid - 1) // grid))
                for k in range(0, len(pdf.pages), 2):
                    positions = []
                    for page in pdf.pages[k : k + 2]:
                        self.assertAlmostEqual(float(page.mediabox.width), 612)
                        self.assertAlmostEqual(float(page.mediabox.height), 792)
                        located = {}

                        def visit(text, cm, tm, font, size):
                            if text.strip().startswith("KC-"):
                                located[text.strip()] = (tm[4], tm[5])

                        page.extract_text(visitor_text=visit)
                        positions.append(located)
                    self.assertEqual(set(positions[0]), set(positions[1]))
                    cw = 270
                    ch = 720 / (grid // 2)
                    for id, (fx, fy) in positions[0].items():
                        bx, by = positions[1][id]
                        from reportlab.pdfbase.pdfmetrics import stringWidth

                        id_width = stringWidth(id, "Cards", 7)
                        fc = (fx + id_width + 15 - cw / 2, fy + 19 - ch / 2)
                        bc = (bx + id_width + 15 - cw / 2, by + 19 - ch / 2)
                        expected = (
                            (612 - fc[0], fc[1])
                            if flip == "long-edge"
                            else (fc[0], 792 - fc[1])
                        )
                        self.assertAlmostEqual(expected[0], bc[0], places=3)
                        self.assertAlmostEqual(expected[1], bc[1], places=3)
                self.assertNotIn("Fjala", pdf.pages[1].extract_text())
                self.assertNotIn("Word", pdf.pages[0].extract_text())
                self.assertEqual(
                    len(
                        json.loads(path.with_suffix(".manifest.json").read_text())[
                            "cards"
                        ]
                    ),
                    19,
                )

    def test_layout_failure_preserves_previous_pdf(self):
        self.seed()
        path = self.root / "out.pdf"
        path.write_bytes(b"previous")
        self.s.update(1, {"albanian": "w" * 299}, 1)
        with self.assertRaises(ValueError):
            render_pdf(self.s, self.s.cards(), path, allow_proposed=True)
        self.assertEqual(path.read_bytes(), b"previous")

    def test_html_escapes_text(self):
        self.seed()
        self.s.update(1, {"notes": "<script>alert(1)</script>"}, 1)
        path = self.root / "review.html"
        review_html(self.s, self.s.cards(), path)
        text = path.read_text()
        self.assertNotIn("<script>", text)
        self.assertIn("&lt;script&gt;", text)


if __name__ == "__main__":
    unittest.main()
